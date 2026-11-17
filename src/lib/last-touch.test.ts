import { describe, expect, it } from 'vitest'
import { daysSinceTouch, formatTouchAgo, getLastTouch, isStaleTouch, isTrackedStatus } from './last-touch'

const NOW = new Date('2026-11-17T12:00:00Z').getTime()
const days = (iso: string | null, extra = {}) => daysSinceTouch({ last_contacted_date: iso, ...extra }, NOW)

describe('getLastTouch', () => {
  it('urutan prioritas: last_contacted_date -> updated_at -> lead_entry_date', () => {
    expect(getLastTouch({ last_contacted_date: 'A', updated_at: 'B', lead_entry_date: 'C' })).toBe('A')
    expect(getLastTouch({ last_contacted_date: null, updated_at: 'B', lead_entry_date: 'C' })).toBe('B')
    expect(getLastTouch({ last_contacted_date: null, updated_at: null, lead_entry_date: 'C' })).toBe('C')
    expect(getLastTouch({})).toBeNull()
  })
})

describe('daysSinceTouch', () => {
  it('menghitung hari penuh (kasus Fredy ap: 6 Nov -> 11 hari)', () => {
    expect(days('2026-11-06T12:00:00Z')).toBe(11)
  })

  it('membulatkan ke bawah', () => {
    expect(days('2026-11-13T13:00:00Z')).toBe(3) // 3 hari 23 jam
  })

  it('fallback ke updated_at lalu lead_entry_date', () => {
    expect(days(null, { updated_at: '2026-11-10T12:00:00Z' })).toBe(7)
    expect(days(null, { lead_entry_date: '2026-11-01T12:00:00Z' })).toBe(16)
  })

  it('tanpa tanggal atau tanggal rusak -> null', () => {
    expect(days(null)).toBeNull()
    expect(days('bukan-tanggal')).toBeNull()
  })

  it('tanggal di masa depan tidak negatif', () => {
    expect(days('2026-11-20T12:00:00Z')).toBe(0)
  })
})

describe('isStaleTouch (D+3 = lebih dari 3 hari)', () => {
  it('3 hari belum stale, 4 hari stale', () => {
    expect(isStaleTouch(3)).toBe(false)
    expect(isStaleTouch(4)).toBe(true)
  })

  it('3 hari 23 jam belum stale', () => {
    expect(isStaleTouch(days('2026-11-13T13:00:00Z'))).toBe(false)
  })

  it('tanggal tidak diketahui tidak dianggap stale', () => {
    expect(isStaleTouch(null)).toBe(false)
  })
})

describe('isTrackedStatus', () => {
  it.each([
    'Input Manual',
    'Bridging',
    'Pitching',
    'In-doubt',
    'Menunggu arahan selanjutnya',
    'Menunggu jadwal pemetaan',
    'Menunggu hasil pemetaan',
    'Menunggu pembayaran seat-lock',
  ])('%s dilacak', (s) => {
    expect(isTrackedStatus(s)).toBe(true)
  })

  it.each(['Closing Seat Lock', 'Jalur Akselerasi', 'Cold Leads', 'Failed', 'Not Interested', 'Not Eligible'])(
    '%s tidak dilacak',
    (s) => {
      expect(isTrackedStatus(s)).toBe(false)
    }
  )
})

describe('formatTouchAgo', () => {
  it('format', () => {
    expect(formatTouchAgo(null)).toBe('—')
    expect(formatTouchAgo(0)).toBe('Hari ini')
    expect(formatTouchAgo(5)).toBe('5 hari lalu')
  })
})
