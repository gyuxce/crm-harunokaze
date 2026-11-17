-- FILE 1 dari 3 — DRY-RUN. Hanya baca, aman dijalankan berkali-kali.
-- Hasilnya satu baris angka. Catat delete_total, dan kirim hasilnya ke Claude.
-- Buka file ini sendirian di SQL editor, lalu Run.

-- BAGIAN 1 — DRY-RUN (hanya baca, aman dijalankan berkali-kali)
with resolved as (
  select
    l.id,
    coalesce(
      o.entity,
      case when lower(coalesce(l.source_campaign, '')) like '%driver%' then 'KFI' else 'HNZ' end
    ) as entity,
    l.current_status in (
      'Menunggu jadwal pemetaan',
      'Menunggu hasil pemetaan',
      'Menunggu jadwal expert consultation',
      'Menunggu pembayaran seat-lock',
      'Jalur Akselerasi',
      'Closing Seat Lock',
      'Cold Leads',
      'Failed'
    ) as is_stage3
  from public.leads l
  left join public.campaign_entity_overrides o
    on o.source_campaign = coalesce(l.source_campaign, '')
),
flagged as (
  select id, entity, is_stage3, (entity = 'KFI' or is_stage3) as keep
  from resolved
)
select
  count(*)                                                    as total_leads,
  count(*) filter (where keep)                                as keep_total,
  count(*) filter (where entity = 'KFI' and not is_stage3)    as keep_kfi_only,
  count(*) filter (where is_stage3 and entity <> 'KFI')       as keep_stage3_only,
  count(*) filter (where is_stage3 and entity = 'KFI')        as keep_both,
  count(*) filter (where not keep)                            as delete_total,
  count(*) filter (where not keep and exists (
    select 1 from public.payments p
    where p.lead_id = flagged.id and p.verification_status = 'verified'
  ))                                                          as delete_with_verified_payment,
  count(*) filter (where not keep and (
    exists (select 1 from public.pemetaan pm where pm.lead_id = flagged.id)
    or exists (select 1 from public.expert_consultations ec where ec.lead_id = flagged.id)
  ))                                                          as delete_with_pemetaan_or_expert,
  count(*) filter (where not keep and exists (
    select 1 from public.danacita_applications d where d.lead_id = flagged.id
  ))                                                          as delete_with_danacita
from flagged;


