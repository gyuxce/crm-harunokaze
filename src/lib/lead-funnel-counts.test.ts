import { describe, expect, it } from 'vitest'
import { countLeadFunnel } from './lead-funnel-counts'

const rows = (statuses: string[]) => statuses.map((current_status) => ({ current_status }))

describe('countLeadFunnel', () => {
  it('menghitung tiap tahap tepat satu kali', () => {
    const counts = countLeadFunnel(
      rows([
        'Input Manual',
        'New Lead', // alias lama Input Manual
        'Bridging',
        'In-doubt',
        'Menunggu arahan selanjutnya',
        'Menunggu hasil pemetaan',
        'Jalur Akselerasi',
        'Closing Seat Lock',
        'Cold Leads',
        'Failed',
        'Not Interested',
      ])
    )
    expect(counts).toEqual({ total: 11, stage1: 3, stage2: 2, stage3: 3, won: 1, exit: 3 })
  })

  it('Cold Leads / Failed masuk "exit", bukan stage3 (tidak dihitung ganda)', () => {
    const counts = countLeadFunnel(rows(['Cold Leads', 'Failed']))
    expect(counts.stage3).toBe(0)
    expect(counts.exit).toBe(2)
  })

  it('daftar kosong', () => {
    expect(countLeadFunnel([])).toEqual({ total: 0, stage1: 0, stage2: 0, stage3: 0, won: 0, exit: 0 })
  })

  it('status expert yang sudah dihapus tidak dihitung di tahap mana pun', () => {
    const counts = countLeadFunnel(rows(['Menunggu jadwal expert consultation']))
    expect(counts).toEqual({ total: 1, stage1: 0, stage2: 0, stage3: 0, won: 0, exit: 0 })
  })
})
