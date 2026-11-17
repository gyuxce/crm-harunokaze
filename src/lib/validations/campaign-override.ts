import { z } from 'zod'

/**
 * Input untuk menyimpan mapping campaign -> entitas (HNZ / KFI).
 *
 * `sourceCampaign` sengaja TIDAK di-trim: kunci mapping dicocokkan persis dengan
 * leads.source_campaign (lihat src/lib/entity.ts), dan ada campaign dengan spasi di ujung.
 * Daftar entitas harus sama dengan ENTITIES di src/lib/entity.ts (dijaga oleh tes).
 */
export const campaignOverrideSchema = z.object({
  sourceCampaign: z.string().min(1, 'Nama campaign wajib diisi').max(500, 'Nama campaign terlalu panjang'),
  entity: z.enum(['HNZ', 'KFI']),
})

export type CampaignOverrideInput = z.infer<typeof campaignOverrideSchema>
