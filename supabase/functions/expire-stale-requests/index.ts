import { createClient } from 'https://esm.sh/@supabase/supabase-admin@2'

/**
 * Scheduled Edge Function: expire-stale-requests
 *
 * Called by a Supabase scheduled function (pg_cron or external cron)
 * every 15–30 minutes. Invokes the `expire_stale_requests()` database
 * function which marks active requests past their `expires_at` as 'expired'.
 *
 * Deploy:  supabase functions deploy expire-stale-requests
 * Schedule: supabase functions schedule expire-stale-requests --cron "*/15 * * * *"
 */

Deno.serve(async (req) => {
  // Only allow scheduled invocations (cron sends an Authorization header
  // or we verify the request comes from the Supabase scheduler).
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { data, error } = await supabase.rpc('expire_stale_requests')

    if (error) {
      console.error('Error expiring stale requests:', error)
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Expired ${data} stale request(s)`)

    return new Response(
      JSON.stringify({ success: true, expired: data }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
