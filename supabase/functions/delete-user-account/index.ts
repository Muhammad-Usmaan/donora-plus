/**
 * Edge Function: delete-user-account
 *
 * Permanently deletes the authenticated user's account:
 *   1. Cleans up device_tokens and donor_reports (explicit DELETE)
 *   2. Removes storage objects (profile images + verification docs)
 *   3. Deletes the profile row (service role bypasses RLS)
 *   4. Deletes the Auth user via Admin API → CASCADE removes remaining
 *      FK-dependent rows (blood_requests, request_responses, conversations,
 *      messages, notifications, verification_submissions, admin_audit_log)
 *
 * ⚠️  CASCADE WARNING — conversations & messages:
 *     Conversations use ON DELETE CASCADE for both participant FKs.
 *     Deleting a profile therefore destroys the conversation row and ALL
 *     its messages — including the OTHER participant's messages.  This is
 *     a known data-loss trade-off flagged for a future schema redesign
 *     (soft-delete participants or introduce a system placeholder user).
 *
 * Secrets required (Edge Function secrets, never exposed to client):
 *   SUPABASE_URL              — project URL (auto-injected by Supabase)
 *   SUPabase_SERVICE_ROLE_KEY — service role key (auto-injected by Supabase)
 *
 * Deploy: supabase functions deploy delete-user-account
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  // ── 1. Extract user ID from the verified JWT ────────────────────────────
  // This function is deployed with verify_jwt=true, so Supabase's edge
  // runtime already validated the JWT signature before we reach here.
  // An invalid/missing JWT results in an automatic 401.
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 })
  }

  let userId: string
  try {
    const token = authHeader.replace('Bearer ', '')
    const payload = JSON.parse(atob(token.split('.')[1]))
    userId = payload.sub
    if (!userId) throw new Error('no sub')
  } catch {
    return new Response(
      JSON.stringify({ success: false, error: 'Invalid token' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // ── 2. Self-only guard ──────────────────────────────────────────────────
  // The body may contain { userId }, but we always use the JWT uid.
  let body: { userId?: string } = {}
  try {
    body = await req.json()
  } catch {
    // No body is fine — we use the JWT uid regardless.
  }

  if (body.userId && body.userId !== userId) {
    return new Response(
      JSON.stringify({
        success: false,
        error: 'You can only delete your own account',
      }),
      { status: 403, headers: { 'Content-Type': 'application/json' } },
    )
  }

  try {
    // Service-role client (bypasses RLS for cleanup writes).
    const admin = createClient(supabaseUrl, supabaseServiceKey)

    // ── 3. Explicit cleanup before CASCADE ────────────────────────────────

    // 3a. Device tokens (redundant with CASCADE, but explicit for clarity).
    await admin.from('device_tokens').delete().eq('user_id', userId)

    // 3b. Donor reports FILED BY this user.
    //     Reports ABOUT this user (reported_user_id) are preserved — they
    //     are admin audit records and must survive account deletion.
    await admin.from('donor_reports').delete().eq('reporter_id', userId)

    // 3c. Storage objects — profile images and verification documents.
    //     Best-effort; failures are non-fatal (objects become orphaned
    //     but inaccessible after the profile/auth user is gone).
    try {
      await admin.storage.from('profile-images').remove([`${userId}/`])
    } catch (e) {
      console.warn('Storage cleanup (profile-images):', String(e))
    }
    try {
      await admin.storage.from('verifications').remove([`${userId}/`])
    } catch (e) {
      console.warn('Storage cleanup (verifications):', String(e))
    }

    // ── 4. Delete profile row ─────────────────────────────────────────────
    // Service role bypasses RLS.  We delete explicitly rather than relying
    // on the auth.users CASCADE, because RLS DELETE policies on public.profiles
    // may not be triggered by a service-role FK cascade from auth.users.
    const { error: profileDeleteError } = await admin
      .from('profiles')
      .delete()
      .eq('id', userId)

    if (profileDeleteError) {
      console.error('Profile delete error:', profileDeleteError)
      // If the profile was already gone (orphan state), continue anyway —
      // we still need to delete the auth user below.
      if (
        !profileDeleteError.message?.includes('not found') &&
        profileDeleteError.code !== 'PGRST116'
      ) {
        // PGRST116 = "not found / zero rows" — profile already deleted.
        throw new Error(
          `Failed to delete profile: ${profileDeleteError.message}`,
        )
      }
    }

    // ── 5. Delete the Auth user via Admin API ─────────────────────────────
    // This is the critical step that was missing before.  Without it, the
    // auth.users row survives and the user can log back in.
    const { error: deleteUserError } = await admin.auth.admin.deleteUser(
      userId,
    )

    if (deleteUserError) {
      console.error('Auth user delete error:', deleteUserError)
      throw new Error(`Failed to delete auth user: ${deleteUserError.message}`)
    }

    console.log(`Account deleted: ${userId}`)

    return new Response(
      JSON.stringify({ success: true, userId }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('delete-user-account error:', err)
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Internal server error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
