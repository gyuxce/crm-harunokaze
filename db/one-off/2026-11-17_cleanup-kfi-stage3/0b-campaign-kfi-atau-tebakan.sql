-- FILE 0b — Campaign yang perlu dicek mata. Hanya baca.
-- Menampilkan campaign yang (a) berlabel KFI, (b) labelnya hanya TEBAKAN, atau (c) mengandung kata "driver".
-- Kirim hasilnya ke Claude.

select *
from (
  select
    l.source_campaign,
    count(*) as jumlah_lead,
    coalesce(o.entity, case when lower(coalesce(l.source_campaign,'')) like '%driver%' then 'KFI' else 'HNZ' end) as entity,
    case when o.entity is null then 'TEBAKAN' else 'override' end as sumber
  from public.leads l
  left join public.campaign_entity_overrides o on o.source_campaign = coalesce(l.source_campaign,'')
  group by 1, 3, 4
) c
where c.entity = 'KFI'
   or c.sumber = 'TEBAKAN'
   or lower(coalesce(c.source_campaign,'')) like '%driver%'
order by c.sumber, c.jumlah_lead desc;
