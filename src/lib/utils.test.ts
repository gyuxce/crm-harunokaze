import { afterEach, describe, expect, it, vi } from 'vitest'
import { generateWALink, getTodayInWIB } from './utils'
import { isPaymentChannel, paymentChannelLabel } from './payment-channel'
import { getStageBadgeClasses, isLostOutcomeStatus, isWonStatus } from './brand'

describe('generateWALink', () => {
  it('0 di depan diganti kode negara 62', () => {
    expect(generateWALink('08123456789')).toBe('https://wa.me/628123456789')
  })

  it('karakter non-angka dibuang', () => {
    expect(generateWALink('+62 812-3456-789')).toBe('https://wa.me/628123456789')
  })

  it('pesan di-encode', () => {
    expect(generateWALink('08123456789', 'Halo kak & terima kasih')).toBe(
      'https://wa.me/628123456789?text=Halo%20kak%20%26%20terima%20kasih'
    )
  })
})

describe('getTodayInWIB', () => {
  afterEach(() => {
    vi.useRealTimers()
  })

  it('memakai zona Asia/Jakarta (UTC+7), bukan UTC', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-11-17T20:00:00Z')) // 03:00 WIB tanggal 18
    expect(getTodayInWIB()).toBe('2026-11-18')
    vi.setSystemTime(new Date('2026-11-17T16:59:59Z')) // 23:59:59 WIB tanggal 17
    expect(getTodayInWIB()).toBe('2026-11-17')
  })
})

describe('payment channel', () => {
  it('label dan validasi', () => {
    expect(paymentChannelLabel('danacita')).toBe('Danacita')
    expect(paymentChannelLabel('lainnya')).toBe('lainnya') // fallback ke nilai asli
    expect(isPaymentChannel('web')).toBe(true)
    expect(isPaymentChannel('Transfer')).toBe(false)
  })
})

describe('status won / lost', () => {
  it('Closing Seat Lock won; Cold/Failed/Not Interested lost', () => {
    expect(isWonStatus('Closing Seat Lock')).toBe(true)
    for (const s of ['Cold Leads', 'Failed', 'Not Interested', 'Not Eligible']) expect(isLostOutcomeStatus(s)).toBe(true)
    expect(isLostOutcomeStatus('Bridging')).toBe(false)
  })

  it('badge lost untuk status keluar', () => {
    expect(getStageBadgeClasses('Failed')).toBe('stage-badge stage-badge-lost')
  })
})
