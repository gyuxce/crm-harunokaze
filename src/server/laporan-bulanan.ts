import 'server-only'
import { requireUser } from './auth'

/** Data laporan menggunakan sesi pengguna sehingga aturan RLS tetap berlaku. */
export async function getLaporanBulananData() {
  const { supabase } = await requireUser()
  const [leads, payments, danacita] = await Promise.all([
    supabase.from('leads').select('id, current_status, source_campaign, lead_entry_date').limit(5000),
    supabase.from('payments').select('lead_id, payment_type, amount, payment_date, verification_status').eq('verification_status', 'verified').limit(5000),
    supabase.from('danacita_applications').select('id, status, created_at').limit(2000),
  ])
  return {
    leads: leads.data ?? [],
    payments: payments.data ?? [],
    danacita: danacita.data ?? [],
  }
}
