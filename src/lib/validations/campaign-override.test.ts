import { describe, expect, it } from 'vitest'
import { ENTITIES } from '@/lib/entity'
import { campaignOverrideSchema } from './campaign-override'

describe('campaignOverrideSchema', () => {
  it('menerima input valid', () => {
    const r = campaignOverrideSchema.safeParse({ sourceCampaign: 'Program Driver Jepang', entity: 'KFI' })
    expect(r.success).toBe(true)
  })

  it('daftar entitas sama dengan ENTITIES di entity.ts', () => {
    for (const entity of ENTITIES) {
      expect(campaignOverrideSchema.safeParse({ sourceCampaign: 'X', entity }).success, entity).toBe(true)
    }
    expect(campaignOverrideSchema.safeParse({ sourceCampaign: 'X', entity: 'LAINNYA' }).success).toBe(false)
  })

  it('menolak nama campaign kosong atau terlalu panjang', () => {
    expect(campaignOverrideSchema.safeParse({ sourceCampaign: '', entity: 'HNZ' }).success).toBe(false)
    expect(campaignOverrideSchema.safeParse({ sourceCampaign: 'a'.repeat(501), entity: 'HNZ' }).success).toBe(false)
  })

  it('tidak men-trim nama campaign (kunci dicocokkan persis, termasuk spasi di ujung)', () => {
    const r = campaignOverrideSchema.parse({ sourceCampaign: 'Konstruksi Y ', entity: 'HNZ' })
    expect(r.sourceCampaign).toBe('Konstruksi Y ')
  })

  it('menolak tipe yang salah', () => {
    expect(campaignOverrideSchema.safeParse({ sourceCampaign: 123, entity: 'HNZ' }).success).toBe(false)
    expect(campaignOverrideSchema.safeParse({ entity: 'HNZ' }).success).toBe(false)
    expect(campaignOverrideSchema.safeParse(null).success).toBe(false)
  })
})
