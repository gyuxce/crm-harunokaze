# Database (Supabase / PostgreSQL)

Database CRM ini adalah Postgres di Supabase. Aplikasi mengaksesnya lewat Supabase (Auth + API),
bukan koneksi Postgres langsung.

## Isi folder

| Folder | Isi | Boleh dijalankan lagi? |
|---|---|---|
| `baseline/` | **Skema `public` produksi** per 2026-11-17 (hasil `pg_dump --schema-only`). | Ya, untuk membangun database baru. **Ini sumber kebenaran.** |
| `schema/` | Riwayat file SQL yang dulu dijalankan satu per satu (001–011). | **Tidak untuk membangun database baru.** Lihat peringatan di bawah. |
| `one-off/` | Skrip sekali jalan (migrasi data, pembersihan). Sudah dijalankan. | **Jangan** dijalankan ulang tanpa memahami isinya. |

## Peringatan penting

- `schema/001_base_schema_DESTRUCTIVE.sql` melakukan `DROP TABLE ... CASCADE` pada `leads`, `users`,
  `payments`, dan tabel lain. Menjalankannya di produksi **menghapus semua data**.
- File di `schema/` **tidak lengkap** dibanding produksi. Saat dibandingkan (2026-11-17) produksi punya hal
  yang tidak tercatat di file mana pun di repo:
  - kolom `leads.created_by`, `updated_by`, `whatsapp_normalized`, `duplicate_of`, `duplicate_reason`
    (aplikasi memakai `updated_by`);
  - fungsi `check_duplicate_phone()`, `auto_schedule_followups()`, dan versi `save_work_queue_fast` /
    `update_lead_core_fast` yang berbeda dari repo;
  - index unik `leads_whatsapp_normalized_unique`, dan tabel sisa `_prisma_migrations`.
  
  Sebaliknya `leads.funnel_stage` (dari `007_funnel-stage-optional.sql`) ada di repo tetapi **tidak ada** di produksi.
  Membangun database dari `schema/` menghasilkan database yang membuat aplikasi tidak berfungsi.

## Membuat database baru (mis. pindah ke VPS)

1. Pasang Postgres/Supabase tujuan.
2. Jalankan `baseline/2026-11-17_prod_public_schema.sql` (skema `public`).
3. Pindahkan data dengan `pg_dump --data-only --schema=public` (+ schema `auth` supaya akun login ikut,
   dan pastikan trigger `on_auth_user_created` pada `auth.users` ada; ia memanggil `public.handle_new_user()`).
4. Samakan `NEXT_PUBLIC_SUPABASE_URL` dan `NEXT_PUBLIC_SUPABASE_ANON_KEY` di aplikasi.

Setiap perubahan skema berikutnya sebaiknya disimpan sebagai file baru berurut di `schema/` (012, 013, ...)
dan baseline diperbarui kalau sudah jauh berbeda.

## Mengambil backup

Paket gratis Supabase tidak punya backup harian. Ambil manual dari terminal (Postgres client 17,
`brew install postgresql@17`; pakai Session pooler dari Supabase → Connect):

```
read -s PGPASSWORD; export PGPASSWORD
/opt/homebrew/opt/postgresql@17/bin/pg_dump -h <HOST_POOLER> -p 5432 -U postgres.<PROJECT_REF> \
  -d postgres --schema=public -Fc -f ~/Documents/crm-backup-$(date +%F).dump
unset PGPASSWORD
```

Simpan hasilnya di luar repo (berisi data pelanggan).

## one-off (urutan kronologis)

| File | Fungsi |
|---|---|
| `2026-07-25_prd-v3-status-normalize.sql` / `..._status-rollback.sql` | Normalisasi status lama ke status PRD V3 (+ rollback). |
| `2026-07-26_prd-v3-keep-important.sql` | Hapus lead lama kecuali yang penting. |
| `2026-07-26_prd-v3-delete-pitching.sql` | Hapus lead berstatus Pitching. |
| `2026-07-26_prd-v3-rename-input-manual.sql` | Ganti nama status "New Lead" → "Input Manual". |
| `2026-07-26_prd-v3-delete-unused-statuses.sql` | Hapus lead berstatus tak terpakai. |
| `2026-11-17_cleanup-kfi-stage3/` | Pertahankan hanya lead KFI/Driver dan semua lead Stage 3 (2135 → 361). Berisi file 0–3 yang dijalankan berurutan; file 3 menghapus permanen dan memakai angka konfirmasi dari dry-run. |
