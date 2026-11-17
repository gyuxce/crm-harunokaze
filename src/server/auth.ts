import 'server-only'
import { createClient } from '@/lib/supabase/server'
import { isOwnerLikeRole } from '@/lib/brand'

/**
 * Pemeriksaan login / role untuk Data Access Layer (src/server/*).
 *
 * Server Action bisa dipanggil lewat POST langsung (bukan hanya dari UI), jadi SETIAP
 * action harus memeriksa login sendiri. Klien Supabase di sini memakai sesi (cookie) pengguna,
 * jadi aturan RLS di database tetap berlaku seperti sebelumnya.
 */
export class AuthError extends Error {
  constructor(message: 'Unauthorized' | 'Forbidden') {
    super(message)
    this.name = 'AuthError'
  }
}

export async function requireUser() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) throw new AuthError('Unauthorized')
  return { supabase, user }
}

/** Hanya role admin / owner (sama dengan aturan tab Pengaturan di UI). */
export async function requireOwnerLike() {
  const { supabase, user } = await requireUser()
  const { data } = await supabase.from('users').select('role').eq('id', user.id).maybeSingle()
  if (!isOwnerLikeRole(data?.role)) throw new AuthError('Forbidden')
  return { supabase, user }
}
