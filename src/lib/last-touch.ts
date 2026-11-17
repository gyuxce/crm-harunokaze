/**
 * "Terakhir disentuh" (last touch) tracker — satu sumber supaya dashboard, daftar Leads,
 * Stage 1 dan Stage 2 tidak diam-diam beda hitungan.
 *
 * Last touch = last_contacted_date, kalau kosong updated_at, kalau kosong lead_entry_date.
 * Stale = lebih dari STAGE3_ATTENTION_STALE_DAYS hari (D+3).
 * Tidak perlu dilacak = status yang sudah selesai / keluar (STAGE3_ATTENTION_EXCLUDED_STATUSES
 * + Not Interested / Not Eligible).
 */
import { STAGE3_ATTENTION_EXCLUDED_STATUSES, STAGE3_ATTENTION_STALE_DAYS } from '@/lib/prd-stages'
import { isLostOutcomeStatus } from '@/lib/brand'

export type TouchFields = {
  last_contacted_date?: string | null
  updated_at?: string | null
  lead_entry_date?: string | null
}

const DAY_MS = 86400000

/** Timestamp last-touch lead, atau null kalau tidak ada tanggal sama sekali. */
export function getLastTouch(lead: TouchFields): string | null {
  return lead.last_contacted_date || lead.updated_at || lead.lead_entry_date || null
}

/** Jumlah hari penuh sejak last touch, atau null kalau tidak diketahui. */
export function daysSinceTouch(lead: TouchFields, now: number = Date.now()): number | null {
  const last = getLastTouch(lead)
  if (!last) return null
  const t = new Date(last).getTime()
  if (Number.isNaN(t)) return null
  return Math.max(0, Math.floor((now - t) / DAY_MS))
}

/** Lebih dari D+3 hari tanpa sentuhan. */
export function isStaleTouch(days: number | null): boolean {
  return days !== null && days > STAGE3_ATTENTION_STALE_DAYS
}

/** Status yang masih perlu dipantau (bukan seat lock / akselerasi / cold / failed / not interested). */
export function isTrackedStatus(status: string): boolean {
  if ((STAGE3_ATTENTION_EXCLUDED_STATUSES as readonly string[]).includes(status)) return false
  return !isLostOutcomeStatus(status)
}

export function formatTouchAgo(days: number | null): string {
  if (days === null) return '—'
  if (days === 0) return 'Hari ini'
  return `${days} hari lalu`
}
