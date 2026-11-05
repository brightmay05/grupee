import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.trim()
const key = (import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined)?.trim()
const hasValidUrl = Boolean(url && /^https?:\/\//i.test(url))

let client: SupabaseClient | null = null
try {
  if (hasValidUrl && key) {
    client = createClient(url!, key, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
  }
} catch (error) {
  console.error('Supabase configuration is invalid', error)
  client = null
}

export const isSupabaseConfigured = Boolean(client)
export const supabase = client
