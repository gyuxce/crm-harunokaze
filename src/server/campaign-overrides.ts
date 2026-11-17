import 'server-only'
import type { Entity } from '@/lib/entity'
import { campaignOverrideSchema, type CampaignOverrideInput } from '@/lib/validations/campaign-override'
import { requireOwnerLike, requireUser } from './auth'

export type CampaignOverride = { source_campaign: string; entity: Entity }

/** Semua mapping campaign -> entitas. Boleh dibaca semua pengguna yang login (dipakai badge HNZ/KFI). */
export async function listCampaignOverrides(): Promise<CampaignOverride[]> {
  const { supabase } = await requireUser()
  const { data, error } = await supabase.from('campaign_entity_overrides').select('source_campaign, entity')
  if (error) throw new Error(error.message)
  return (data ?? []) as CampaignOverride[]
}

/** Simpan / ubah mapping. Hanya admin / owner. `updated_by` diambil dari sesi, bukan dari klien. */
export async function upsertCampaignOverride(input: CampaignOverrideInput): Promise<void> {
  const parsed = campaignOverrideSchema.parse(input)
  const { supabase, user } = await requireOwnerLike()
  const { error } = await supabase
    .from('campaign_entity_overrides')
    .upsert({ source_campaign: parsed.sourceCampaign, entity: parsed.entity, updated_by: user.id })
  if (error) throw new Error(error.message)
}
