import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405)

  try {
    const { paths } = await req.json()
    if (!Array.isArray(paths) || paths.length === 0 || paths.length > 100) {
      return json({ error: 'paths must be an array with 1-100 items' }, 400)
    }

    const cleanPaths = [...new Set(paths)]
      .filter((p): p is string => typeof p === 'string' && p.length > 0 && p.length < 1000)

    const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}')
    const secretKey = secretKeys.default || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!secretKey) return json({ error: 'Server storage key is not configured' }, 500)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      secretKey,
      { auth: { persistSession: false, autoRefreshToken: false } },
    )

    // Only allow paths that are currently referenced by the public portfolio state.
    // This prevents this public endpoint from becoming a generic Storage file browser.
    const { data: state, error: stateError } = await supabase
      .from('portfolio_state')
      .select('items,bg_path')
      .eq('id', 1)
      .maybeSingle()

    if (stateError) throw stateError

    const allowed = new Set<string>()
    for (const item of Array.isArray(state?.items) ? state.items : []) {
      if (typeof item?.cloudPath === 'string') allowed.add(item.cloudPath)
    }
    if (typeof state?.bg_path === 'string') allowed.add(state.bg_path)

    const requested = cleanPaths.filter((path) => allowed.has(path))
    if (requested.length === 0) return json({ urls: {}, expiresIn: 900 })

    const { data, error } = await supabase.storage
      .from('portfolio-media')
      .createSignedUrls(requested, 900)

    if (error) throw error

    const urls: Record<string, string> = {}
    for (const row of data || []) {
      if (row.path && row.signedUrl) urls[row.path] = row.signedUrl
    }

    return json({ urls, expiresIn: 900 })
  } catch (error) {
    console.error(error)
    return json({ error: error instanceof Error ? error.message : 'Unexpected error' }, 500)
  }
})
