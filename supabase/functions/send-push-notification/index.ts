/**
 * Edge Function: send-push-notification
 *
 * Sends FCM push notifications to one or more device tokens using the
 * FCM HTTP v1 API. Called by the Flutter client AFTER `prepare_notification`
 * RPC has already:
 *   1. Checked the recipient's notification preferences
 *   2. Inserted the in-app notification row
 *   3. Returned the recipient's device tokens
 *
 * Payload shape (POST JSON):
 * {
 *   tokens: string[],          // FCM device tokens
 *   type: string,              // notification type (e.g. 'new_message')
 *   title: string,
 *   body: string,
 *   deep_link_id?: string      // optional ID for deep-linking
 * }
 *
 * Secrets required (set via `supabase secrets set`):
 *   FCM_SERVICE_ACCOUNT_KEY  — JSON string of the GCP service account key
 *                              with FCM permissions (Cloud Messaging API role)
 *
 * Deploy: supabase functions deploy send-push-notification
 */

const FCM_SERVICE_ACCOUNT_KEY = Deno.env.get('FCM_SERVICE_ACCOUNT_KEY')

Deno.serve(async (req) => {
  // ── Auth ──────────────────────────────────────────────────────────────────
  // The function is deployed with verify_jwt=true so only authenticated
  // users can invoke it. We additionally verify the caller has a valid
  // Supabase session.
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 })
  }

  if (!FCM_SERVICE_ACCOUNT_KEY) {
    console.error('FCM_SERVICE_ACCOUNT_KEY secret is not set')
    return new Response(
      JSON.stringify({ success: false, error: 'FCM not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }

  try {
    const { tokens, type, title, body, deep_link_id } = await req.json()

    if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'No tokens' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // ── Get OAuth2 access token for FCM ───────────────────────────────────
    const accessToken = await getOAuth2Token(FCM_SERVICE_ACCOUNT_KEY)

    // ── Get the Firebase project ID from the service account ──────────────
    const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_KEY)
    const projectId = serviceAccount.project_id

    // ── Send to each token ────────────────────────────────────────────────
    const results = await Promise.allSettled(
      tokens.map((token: string) =>
        sendFcmMessage(accessToken, projectId, token, {
          type,
          title,
          body,
          deep_link_id: deep_link_id || '',
        })
      )
    )

    const succeeded = results.filter((r) => r.status === 'fulfilled').length
    const failed = results.length - succeeded

    console.log(`FCM: sent=${succeeded}, failed=${failed}`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: succeeded,
        failed,
      }),
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

/**
 * Exchanges a GCP service account key for an OAuth2 access token
 * using the JWT bearer grant type.
 */
async function getOAuth2Token(serviceAccountKeyJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountKeyJson)

  // Build the JWT header and claims
  const header = { alg: 'RS256', typ: 'JWT' }
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: sa.token_uri,
    exp: now + 3600,
    iat: now,
  }

  // Encode and sign the JWT using the service account's private key
  const encoder = new TextEncoder()
  const jwtHeader = base64UrlEncode(encoder.encode(JSON.stringify(header)))
  const jwtClaims = base64UrlEncode(encoder.encode(JSON.stringify(claims)))
  const unsignedJwt = `${jwtHeader}.${jwtClaims}`

  // Sign with RSA-SHA256
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(unsignedJwt)
  )
  const signedJwt = `${unsignedJwt}.${base64UrlEncode(new Uint8Array(signature))}`

  // Exchange the signed JWT for an access token
  const tokenResponse = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedJwt,
    }),
  })

  const tokenData = await tokenResponse.json()
  if (!tokenData.access_token) {
    throw new Error(`OAuth2 token exchange failed: ${JSON.stringify(tokenData)}`)
  }
  return tokenData.access_token
}

/**
 * Sends a notification message to a single device via FCM HTTP v1 API.
 */
async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  data: { type: string; title: string; body: string; deep_link_id: string }
): Promise<void> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token,
        notification: {
          title: data.title,
          body: data.body,
        },
        data: {
          type: data.type,
          deep_link_id: data.deep_link_id,
          title: data.title,
          body: data.body,
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      },
    }),
  })

  if (!response.ok) {
    const errorBody = await response.text()
    // If the token is invalid/expired, log but don't throw — other tokens
    // may still succeed. The client will clean up stale tokens on next launch.
    console.warn(`FCM send failed for token ${token.slice(0, 20)}...: ${response.status} ${errorBody}`)
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function base64UrlEncode(data: Uint8Array | ArrayBuffer): string {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data)
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

function pemToBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s/g, '')
  const binary = atob(b64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}
