/**
 * Ambient type declarations for the Deno runtime and esm.sh URL imports
 * used by Supabase Edge Functions.
 *
 * These declarations silence TypeScript diagnostics in the VS Code language
 * server, which has no Deno SDK in this Flutter-centric workspace.
 * The types are intentionally minimal — just enough for compile-time checks.
 * At runtime the real Deno globals and esm.sh modules are provided by the
 * Supabase Edge Functions runtime.
 */

/* eslint-disable @typescript-eslint/no-explicit-any */

// ── Deno runtime globals ────────────────────────────────────────────────────

interface DenoEnv {
  get(key: string): string | undefined
}

declare const Deno: {
  env: DenoEnv
  serve(handler: (req: Request) => Response | Promise<Response>): void
}

// ── esm.sh URL import: @supabase/supabase-js ────────────────────────────────

declare module 'https://esm.sh/@supabase/supabase-js@2' {
  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: Record<string, any>,
  ): any
}

// ── esm.sh URL import: @supabase/supabase-admin (used by expire-stale-requests) ─

declare module 'https://esm.sh/@supabase/supabase-admin@2' {
  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: Record<string, any>,
  ): any
}
