'use server'

import type { Entity } from '@/lib/entity'
import { listCampaignOverrides, upsertCampaignOverride, type CampaignOverride } from '@/server/campaign-overrides'

/** Pembungkus tipis untuk klien. Logika dan pemeriksaan login ada di src/server/. */
export async function getCampaignOverrides(): Promise<CampaignOverride[]> {
  return listCampaignOverrides()
}

export async function saveCampaignOverride(
  sourceCampaign: string,
  entity: Entity
): Promise<{ ok: true } | { ok: false; error: string }> {
  try {
    await upsertCampaignOverride({ sourceCampaign, entity })
    return { ok: true }
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'Gagal menyimpan.' }
  }
}
