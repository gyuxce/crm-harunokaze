'use client'

import { useEffect, useState } from 'react'
import { getCampaignOverrides } from '@/app/actions/campaign-overrides'
import type { Entity } from '@/lib/entity'

/** Fetches campaign_entity_overrides once and exposes it as a lookup map. */
export function useCampaignOverrides(): ReadonlyMap<string, Entity> {
  const [overrides, setOverrides] = useState<ReadonlyMap<string, Entity>>(new Map())

  useEffect(() => {
    let active = true
    getCampaignOverrides()
      .then((rows) => {
        if (active) setOverrides(new Map(rows.map((o) => [o.source_campaign, o.entity])))
      })
      .catch(() => {
        // Sama seperti sebelumnya: gagal memuat = tanpa override (jatuh ke tebakan kata "driver").
      })
    return () => {
      active = false
    }
  }, [])

  return overrides
}
