// Edge Function: qwen-chat
//
// Server-side proxy to the Qwen (DashScope) chat completions API.
// The Flutter client sends the same payload it previously sent directly
// to Qwen; this function injects the API key server-side so the key
// is never embedded in the mobile binary.
//
// Payload shape (POST JSON):
// {
//   messages: Array<{ role: string; content: string }>,
//   model?: string,
//   temperature?: number,
//   max_tokens?: number
// }
//
// Response: same OpenAI-compatible shape the client already parses:
// { choices: [{ message: { content: "..." } }] }
//
// Secrets required (set via Supabase secrets):
//   QWEN_API_KEY — Alibaba Cloud / DashScope API key

const QWEN_API_ENDPOINT =
  'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions'

Deno.serve(async (req) => {
  // ── Auth ────────────────────────────────────────────────────────────────
  // Deployed with verify_jwt=true so the Supabase runtime already rejected
  // invalid JWTs with a 401 before we reach here.
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 })
  }

  const qwenApiKey = Deno.env.get('QWEN_API_KEY')
  if (!qwenApiKey) {
    console.error('QWEN_API_KEY secret is not set')
    return new Response(
      JSON.stringify({ error: 'Chatbot is not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  try {
    const body = await req.json()

    // ── Validate minimum payload ──────────────────────────────────────────
    if (!body.messages || !Array.isArray(body.messages) || body.messages.length === 0) {
      return new Response(
        JSON.stringify({ error: 'messages array is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── Build the upstream request ────────────────────────────────────────
    // Forward the client's payload directly so parsing logic stays intact.
    const upstreamBody = JSON.stringify({
      model: body.model || 'qwen-plus',
      messages: body.messages,
      temperature: body.temperature ?? 0.7,
      max_tokens: body.max_tokens ?? 256,
    })

    // ── Call Qwen API ─────────────────────────────────────────────────────
    const qwenResponse = await fetch(QWEN_API_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${qwenApiKey}`,
      },
      body: upstreamBody,
    })

    const responseText = await qwenResponse.text()

    if (!qwenResponse.ok) {
      // Log the upstream error for debugging but return a sanitized message
      console.error(`Qwen API error ${qwenResponse.status}: ${responseText}`)
      return new Response(
        JSON.stringify({ error: 'Chatbot service temporarily unavailable' }),
        { status: 502, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── Return the upstream response as-is ────────────────────────────────
    // The client parses choices[0].message.content — pass through unchanged.
    return new Response(responseText, {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('qwen-chat error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
