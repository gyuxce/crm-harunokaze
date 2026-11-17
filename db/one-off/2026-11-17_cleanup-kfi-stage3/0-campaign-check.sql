-- FILE 0 — CEK CAMPAIGN. Hanya baca.
-- Menampilkan tiap campaign, jumlah lead, label entity-nya, dan apakah label itu berasal dari
-- Settings (override) atau cuma TEBAKAN (nama mengandung "driver"). Kirim hasilnya ke Claude.

select
  l.source_campaign,
  count(*) as jumlah_lead,
  coalesce(o.entity, case when lower(coalesce(l.source_campaign,'')) like '%driver%' then 'KFI' else 'HNZ' end) as entity,
  case when o.entity is null then 'TEBAKAN' else 'override' end as sumber
from public.leads l
left join public.campaign_entity_overrides o on o.source_campaign = coalesce(l.source_campaign,'')
group by 1, 3, 4
order by sumber, jumlah_lead desc;
