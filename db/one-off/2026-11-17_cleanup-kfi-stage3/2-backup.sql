-- FILE 2 dari 3 — BACKUP. Hanya baca.
-- Run, lalu download hasilnya sebagai CSV dan kirim ke klien. Jalankan setelah file 1 dicek.

-- BAGIAN 2 — BACKUP (hanya baca). Download hasilnya sebagai CSV dari SQL editor.
-- Berisi semua lead yang AKAN DIHAPUS + label entity + jumlah data turunannya.
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
  l.*,
  f.entity                                                                        as entity,
  (select count(*) from public.lead_activities      x where x.lead_id = l.id)     as n_activities,
  (select count(*) from public.follow_ups           x where x.lead_id = l.id)     as n_follow_ups,
  (select count(*) from public.lead_interventions   x where x.lead_id = l.id)     as n_interventions,
  (select count(*) from public.payments             x where x.lead_id = l.id)     as n_payments,
  (select count(*) from public.pemetaan             x where x.lead_id = l.id)     as n_pemetaan,
  (select count(*) from public.expert_consultations x where x.lead_id = l.id)     as n_expert_consultations,
  (select count(*) from public.danacita_applications x where x.lead_id = l.id)    as n_danacita
from public.leads l
join flagged f on f.id = l.id
where not f.keep
order by l.created_at;


