-- FILE 0c — Dari lead yang AKAN DIHAPUS, berapa yang punya data pemetaan / expert yang benar-benar terisi
-- (bukan baris kosong bawaan sistem)? Hanya baca. Kirim hasilnya ke Claude.

with resolved as (
  select l.id,
    coalesce(o.entity, case when lower(coalesce(l.source_campaign, '')) like '%driver%' then 'KFI' else 'HNZ' end) as entity,
    l.current_status in (
      'Menunggu jadwal pemetaan','Menunggu hasil pemetaan','Menunggu jadwal expert consultation',
      'Menunggu pembayaran seat-lock','Jalur Akselerasi','Closing Seat Lock','Cold Leads','Failed'
    ) as is_stage3
  from public.leads l
  left join public.campaign_entity_overrides o on o.source_campaign = coalesce(l.source_campaign, '')
),
to_delete as (select id from resolved where not (entity = 'KFI' or is_stage3))
select
  (select count(*) from to_delete) as delete_total,
  (select count(distinct pm.lead_id) from public.pemetaan pm join to_delete d on d.id = pm.lead_id) as punya_baris_pemetaan,
  (select count(distinct pm.lead_id) from public.pemetaan pm join to_delete d on d.id = pm.lead_id
    where pm.form_status <> 'not_sent' or pm.result_status <> 'not_ready'
       or pm.scheduled_at is not null or pm.completed_at is not null
       or pm.result_ready_at is not null or pm.result_notes is not null) as pemetaan_terisi,
  (select count(distinct ec.lead_id) from public.expert_consultations ec join to_delete d on d.id = ec.lead_id) as punya_baris_expert,
  (select count(distinct ec.lead_id) from public.expert_consultations ec join to_delete d on d.id = ec.lead_id
    where ec.expert_name is not null or ec.scheduled_at is not null or ec.completed_at is not null
       or ec.consultation_result is not null or ec.recommendation is not null or ec.next_step is not null) as expert_terisi;
