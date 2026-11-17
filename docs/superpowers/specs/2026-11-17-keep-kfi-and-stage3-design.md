# Bersihkan data CRM: pertahankan KFI/Driver + semua lead Stage 3

Status: disetujui user (2026-11-17). Ukuran: perubahan kecil (satu file SQL).

Catatan hasil akhir: dijalankan 2026-11-17 (2135 -> 361 lead). Implementasi akhirnya dipecah menjadi
file terpisah di `db/one-off/2026-11-17_cleanup-kfi-stage3/` (0-campaign-check, 0b, 0c, 1-dry-run, 2-backup, 3-delete) dan
bukan satu file `supabase-prd-v3-keep-kfi-and-stage3.sql` seperti ditulis di bawah. Bagian 3 dibuat
sebagai satu pernyataan `do $$` (tanpa temp table / begin-commit) karena editor SQL Supabase
tidak mempertahankan temp table antar pernyataan.

## Intent & why
Klien meminta data di CRM dikurangi. Yang dipertahankan hanya:
1. Lead berlabel KFI / Driver
2. Lead yang sudah sampai Stage 3 (semua status di board Stage 3, termasuk Cold Leads dan Failed; HNZ juga dipertahankan jika di Stage 3)

Semua lead lain dikeluarkan dari CRM, dan klien ingin datanya di-backup dulu.
Aturan keep = (1) ATAU (2). Dibuang = tidak memenuhi keduanya.

## Goals
- Script SQL sekali jalan yang menghapus lead di luar kriteria beserta data turunannya.
- Backup CSV dari data yang dibuang, sebelum penghapusan.
- Dry-run yang menunjukkan jumlah keep/buang sebelum apa pun dihapus.

## Non-goals / anti-goals
- Tidak mengubah kode aplikasi.
- Tidak mengubah script lama (`supabase-prd-v3-keep-important.sql`), riwayatnya dibiarkan.
- Anti-goal: lead KFI ikut terhapus karena logika label KFI di SQL beda dengan di aplikasi.

## Constraints
- Label KFI bukan kolom. Aturannya (src/lib/entity.ts): `campaign_entity_overrides.entity` untuk `leads.source_campaign` jika ada; jika tidak ada, KFI bila campaign mengandung "driver" (case-insensitive); selain itu HNZ. SQL harus meniru ini persis.
- Stage 3 = `leads.current_status` salah satu dari `STAGE3_STATUS_OPTIONS` di src/lib/prd-stages.ts: Menunggu jadwal pemetaan, Menunggu hasil pemetaan, Menunggu jadwal expert consultation, Menunggu pembayaran seat-lock, Jalur Akselerasi, Closing Seat Lock, Cold Leads, Failed.
- Penghapusan permanen. Script dijalankan user di Supabase SQL editor (agent tidak punya akses DB). Backup Supabase disarankan sebelum jalan.
- Child tables yang ikut dihapus: lead_activities, follow_ups, lead_interventions, payments, pemetaan, expert_consultations (pola script lama).

## Approaches
- A (dipilih): satu file SQL baru dengan 3 bagian: dry-run, query backup CSV, hapus dalam transaksi dengan pengaman jumlah. Murah, cocok untuk kerja sekali jalan, mengikuti pola script lama.
- B: tombol "Export lalu hapus" di aplikasi. Lebih nyaman, tetapi kerja dan risiko jauh lebih besar untuk operasi sekali jalan.
- C: soft-delete (flag arsip). Reversible, tetapi klien minta data dikeluarkan dari CRM dan butuh perubahan di semua query aplikasi.

## Design
File: `supabase-prd-v3-keep-kfi-and-stage3.sql`
1. Dry-run (read-only): hitung keep vs buang; dari yang dibuang, hitung yang punya payment verified atau baris pemetaan/expert (data berharga yang akan hilang).
2. Backup: SELECT lead yang akan dibuang (kolom lengkap leads + entity hasil resolve + jumlah child), untuk di-download sebagai CSV.
3. Delete: satu transaksi; kumpulkan id yang dibuang ke temp table, hapus child rows lalu leads; cek jumlah lead terhapus = jumlah dry-run, jika beda `raise exception` (rollback).

## Left to the builder
Penamaan kolom persis di query backup, dan format pesan pengaman.
