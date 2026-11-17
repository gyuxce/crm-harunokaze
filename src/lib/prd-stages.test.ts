import { describe, expect, it } from 'vitest'
import {
  ALL_PRD_STATUSES,
  STAGE1_CURRENT_STATUS_OPTIONS,
  STAGE2_UPDATE_STATUS_OPTIONS,
  STAGE3_ATTENTION_EXCLUDED_STATUSES,
  STAGE3_ATTENTION_STALE_DAYS,
  STAGE3_ATTENTION_STATUSES,
  STAGE3_BOARD_COLUMNS,
  STAGE3_STATUS_OPTIONS,
  getStage3Column,
  isStage2EntryStatus,
  isStage3WonStatus,
  resolvePrdLane,
  resolveStage3DropStatus,
} from './prd-stages'

const REMOVED_EXPERT_STATUS = 'Menunggu jadwal expert consultation'

describe('resolvePrdLane', () => {
  it.each(['Input Manual', 'New Lead', 'Bridging', 'Pitching'])('%s -> stage1', (s) => {
    expect(resolvePrdLane(s)).toBe('stage1')
  })

  it.each(['Interested to Pemetaan', 'Interested to Interview', 'Interested in Webinar', 'In-doubt', 'No Response', 'Menunggu arahan selanjutnya'])(
    '%s -> stage2',
    (s) => {
      expect(resolvePrdLane(s)).toBe('stage2')
    }
  )

  it.each([
    'Menunggu jadwal pemetaan',
    'Menunggu hasil pemetaan',
    'Menunggu pembayaran seat-lock',
    'Jalur Akselerasi',
    'Closing Seat Lock',
    'Cold Leads',
    'Failed',
  ])('%s -> stage3', (s) => {
    expect(resolvePrdLane(s)).toBe('stage3')
  })

  it.each(['Not Interested', 'Not Eligible'])('%s -> exit', (s) => {
    expect(resolvePrdLane(s)).toBe('exit')
  })

  it('status tak dikenal -> other', () => {
    expect(resolvePrdLane('Status Ngawur')).toBe('other')
  })

  it('status expert yang sudah dihapus tidak lagi masuk Stage 3', () => {
    expect(resolvePrdLane(REMOVED_EXPERT_STATUS)).toBe('other')
  })
})

describe('kolom kanban Stage 3', () => {
  it('urutan kolom tanpa kolom expert', () => {
    expect(STAGE3_BOARD_COLUMNS.map((c) => c.key)).toEqual([
      'jadwal_pemetaan',
      'hasil_pemetaan',
      'seatlock',
      'akselerasi',
      'closing',
      'cold',
      'failed',
    ])
  })

  it('setiap status Stage 3 punya tepat satu kolom', () => {
    for (const status of STAGE3_STATUS_OPTIONS) {
      const owners = STAGE3_BOARD_COLUMNS.filter((c) => (c.statuses as readonly string[]).includes(status))
      expect(owners, status).toHaveLength(1)
      expect(getStage3Column(status)).toBe(owners[0].key)
    }
  })

  it('status expert yang sudah dihapus tidak ada di daftar mana pun', () => {
    const lists: readonly string[][] = [
      [...STAGE3_STATUS_OPTIONS],
      [...STAGE2_UPDATE_STATUS_OPTIONS],
      [...ALL_PRD_STATUSES],
      [...STAGE3_ATTENTION_STATUSES],
      STAGE3_BOARD_COLUMNS.flatMap((c) => [...c.statuses]),
    ]
    for (const list of lists) expect(list).not.toContain(REMOVED_EXPERT_STATUS)
    expect(getStage3Column(REMOVED_EXPERT_STATUS)).toBeNull()
  })

  describe('resolveStage3DropStatus', () => {
    it('menjatuhkan ke kolom yang sama mempertahankan status', () => {
      expect(resolveStage3DropStatus('Closing Seat Lock', 'closing')).toBe('Closing Seat Lock')
    })

    it('menjatuhkan ke kolom lain memakai status kolom itu', () => {
      expect(resolveStage3DropStatus('Failed', 'closing')).toBe('Closing Seat Lock')
      expect(resolveStage3DropStatus('Menunggu hasil pemetaan', 'seatlock')).toBe('Menunggu pembayaran seat-lock')
    })

    it('kolom tidak dikenal (mis. kolom expert lama) -> null', () => {
      expect(resolveStage3DropStatus('Failed', 'expert')).toBeNull()
    })
  })
})

describe('tracker "butuh perhatian" Stage 3', () => {
  it('melacak semua status Stage 3 kecuali Closing, Akselerasi, Cold, Failed', () => {
    expect([...STAGE3_ATTENTION_STATUSES]).toEqual([
      'Menunggu jadwal pemetaan',
      'Menunggu hasil pemetaan',
      'Menunggu pembayaran seat-lock',
    ])
    expect([...STAGE3_ATTENTION_EXCLUDED_STATUSES].sort()).toEqual(
      ['Closing Seat Lock', 'Cold Leads', 'Failed', 'Jalur Akselerasi'].sort()
    )
  })

  it('dilacak + dikecualikan = seluruh status Stage 3, tanpa tumpang tindih', () => {
    const tracked = new Set<string>(STAGE3_ATTENTION_STATUSES)
    const excluded = new Set<string>(STAGE3_ATTENTION_EXCLUDED_STATUSES)
    for (const s of STAGE3_STATUS_OPTIONS) expect(tracked.has(s) !== excluded.has(s), s).toBe(true)
    expect(tracked.size + excluded.size).toBe(STAGE3_STATUS_OPTIONS.length)
  })

  it('ambang D+3', () => {
    expect(STAGE3_ATTENTION_STALE_DAYS).toBe(3)
  })
})

describe('helper status', () => {
  it('isStage3WonStatus hanya Closing Seat Lock', () => {
    expect(isStage3WonStatus('Closing Seat Lock')).toBe(true)
    expect(isStage3WonStatus('Jalur Akselerasi')).toBe(false)
  })

  it('isStage2EntryStatus', () => {
    expect(isStage2EntryStatus('In-doubt')).toBe(true)
    expect(isStage2EntryStatus('Bridging')).toBe(false)
  })

  it('Input Manual adalah opsi Stage 1', () => {
    expect(STAGE1_CURRENT_STATUS_OPTIONS).toContain('Input Manual')
  })
})
