/// <reference path="../deno.types.d.ts" />
/**
 * Edge Function: check-email-exists
 *
 * Checks whether an email address is already registered in Supabase Auth.
 * This is needed because signUp() does not throw a clear "email already
 * exists" error (Supabase suppresses it to prevent user enumeration).
 *
 * The check requires the service role key because auth.users is not
 * directly queryable with the anon key.
 *
 * Request:
 *   POST { "email": "user@example.com" }
 *
 * Response:
 *   { "exists": true }  — email is already registered
 *   { "exists": false } — email is available for signup
 *
 * Security:
 *   - Deployed with verify_jwt = false because this is called BEFORE
 *     the user has an account (during signup).  The function only
 *     returns a boolean — no user details are leaked.
 *   - Rate limiting is handled by Supabase's built-in edge function
 *     throttling.
 *
 * Deploy: supabase functions deploy check-email-exists
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  // ── 1. Parse request body ───────────────────────────────────────────────
  let email: string | undefined
  try {
    const body = await req.json()
    email = body.email?.toString().trim().toLowerCase()
  } catch {
    return new Response(
      JSON.stringify({ exists: false, error: 'Invalid request body' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    )
  }

  if (!email || !email.includes('@')) {
    return new Response(
      JSON.stringify({ exists: false, error: 'A valid email is required' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    )
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Service-role client — can query auth.users via admin API.
    const admin = createClient(supabaseUrl, supabaseServiceKey)

    // ── 2. Look up the email in auth.users ────────────────────────────────
    // listUsers with an email filter returns matching users (exact match).
    // We only return a boolean — no user details are leaked.
    const { data: listData, error: listError } =
      await admin.auth.admin.listUsers({ email, page: 1, perPage: 1 })

    if (listError) {
      console.error('listUsers error:', listError)
      return new Response(
        JSON.stringify({ exists: false, error: 'Failed to check email' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const exists = (listData?.users?.length ?? 0) > 0

    return new Response(
      JSON.stringify({ exists }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('check-email-exists error:', err)
    return new Response(
      JSON.stringify({
        exists: false,
        error: 'Internal server error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
