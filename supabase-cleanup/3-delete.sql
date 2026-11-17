-- FILE 3 dari 3 — HAPUS PERMANEN. Jalankan hanya setelah file 1 dicek dan CSV dari file 2 sudah di-download.
-- SUDAH DIJALANKAN 2026-11-17: 2135 -> 361 lead. Menjalankannya lagi tidak menghapus apa pun
-- (script batal karena angka confirmed_delete tidak cocok dengan hitungan sekarang).
-- Angka confirmed_delete di bawah harus sama dengan delete_total dari file 1 (waktu itu 1774).
-- Seluruh file ini SATU pernyataan (do $$ ... $$), jadi atomik: kalau ada guard yang gagal atau error,
-- tidak ada yang terhapus. Tidak memakai begin/commit atau tabel sementara.
-- Kalau batal karena guard: ulangi dari file 1 dan 2.
--
-- Yang dihapus: lead yang BUKAN KFI dan BUKAN di Stage 3, beserta data turunannya
-- (lead_activities, follow_ups, lead_interventions, payments, pemetaan, expert_consultations,
-- danacita_applications). KFI = override di campaign_entity_overrides, atau (jika belum di-assign)
-- nama campaign mengandung "driver". Stage 3 = Menunggu jadwal pemetaan, Menunggu hasil pemetaan,
-- Menunggu jadwal expert consultation, Menunggu pembayaran seat-lock, Jalur Akselerasi,
-- Closing Seat Lock, Cold Leads, Failed.

do $$
declare
  -- >>> HARUS SAMA DENGAN delete_total DARI FILE 1 <<<
  confirmed_delete constant integer := 1774;

  delete_ids      uuid[];
  expected_delete integer;
  total_leads     integer;
  deleted_leads   integer;
begin
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
    select id, (entity = 'KFI' or is_stage3) as keep
    from resolved
  )
  select coalesce(array_agg(id), '{}'::uuid[]) into delete_ids
  from flagged
  where not keep;

  expected_delete := coalesce(cardinality(delete_ids), 0);
  select count(*) into total_leads from public.leads;

  if confirmed_delete is null then
    raise exception 'Batal: isi dulu confirmed_delete dengan angka delete_total dari file 1.';
  end if;

  -- Data berubah sejak dry-run / backup (lead baru masuk atau status berubah)?
  if expected_delete <> confirmed_delete then
    raise exception 'Batal: dry-run bilang % lead akan dihapus, sekarang jadi %. Ulangi file 1 dan 2.',
      confirmed_delete, expected_delete;
  end if;

  -- Pengaman: kalau semua lead akan terhapus, hampir pasti ada bug di kriteria.
  if total_leads > 0 and expected_delete = total_leads then
    raise exception 'Batal: script akan menghapus SEMUA % lead. Periksa kriteria keep.', total_leads;
  end if;

  delete from public.lead_activities       where lead_id = any(delete_ids);
  delete from public.follow_ups            where lead_id = any(delete_ids);
  delete from public.lead_interventions    where lead_id = any(delete_ids);
  delete from public.payments              where lead_id = any(delete_ids);
  delete from public.pemetaan              where lead_id = any(delete_ids);
  delete from public.expert_consultations  where lead_id = any(delete_ids);
  delete from public.danacita_applications where lead_id = any(delete_ids);

  delete from public.leads where id = any(delete_ids);
  get diagnostics deleted_leads = row_count;

  if deleted_leads <> expected_delete then
    raise exception 'Batal: seharusnya hapus % lead tapi yang terhapus %.', expected_delete, deleted_leads;
  end if;

  raise notice 'Selesai: % lead dihapus, % tersisa.', deleted_leads, total_leads - deleted_leads;
end $$;

-- Cek setelah selesai (jalankan terpisah):
-- select count(*) as remaining_leads from public.leads;   -- harus 361
