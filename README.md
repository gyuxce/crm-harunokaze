# CRM Harunokaze

Dashboard CRM untuk tim CRO (HNZ × Wiwitan, juga lead KFI/Driver Jepang): mengelola lead dari masuk
sampai closing seat-lock, pembayaran, pengajuan Danacita, dan laporan bulanan untuk partner.

**Stack:** Next.js 16 (App Router, Turbopack), React 19, Tailwind CSS 4, Supabase (Auth + Postgres),
TanStack Query, Recharts, dnd-kit.

> Next.js di project ini versi baru dengan perubahan API dibanding yang umum dikenal. Baca panduan di
> `node_modules/next/dist/docs/` sebelum menulis kode Next (lihat `AGENTS.md`).

## Menjalankan di lokal

```bash
npm ci
cp .env.example .env.local   # isi dua variabel Supabase (lihat bawah)
npm run dev                  # http://localhost:3000
```

| Perintah | Fungsi |
|---|---|
| `npm run dev` | Server pengembangan |
| `npm run build` / `npm start` | Build dan jalankan produksi |
| `npm run lint` | ESLint |
| `npm test` | Unit test logika murni (Vitest) |

### Variabel lingkungan

| Variabel | Isi |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | URL project Supabase, mis. `https://<ref>.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Publishable / anon key (Project Settings → API Keys). **Jangan** pakai secret / service_role key. |

> `npm run dev` dengan env di atas terhubung ke database yang diisi di env itu. Kalau itu produksi,
> jangan simpan atau ubah data saat mencoba.

## Struktur

```
src/app/(dashboard)/   Halaman: dashboard, leads, stage-1/2/3, danacita, payments, laporan-bulanan, settings, ...
src/app/actions/       Server actions
src/components/        Komponen per fitur (leads, stage3, reports, layout, ...)
src/lib/               Logika bersama
  prd-stages.ts          Status dan alur Stage 1–3 (sumber kebenaran status)
  entity.ts              Label HNZ / KFI dari campaign
  last-touch.ts          Tracker "terakhir disentuh" (D+3)
  lead-funnel-counts.ts  Hitungan funnel
  supabase/              Client Supabase dan tipe
src/server/            Data laporan bulanan dan campaign melalui lapisan server dengan sesi pengguna
db/                    SQL: baseline skema, riwayat, skrip sekali jalan (baca db/README.md)
docs/superpowers/      Catatan desain dan rencana
```

## Database

Lihat [db/README.md](db/README.md). Ringkasnya: skema produksi ada di `db/baseline/`, file di
`db/schema/` hanya riwayat (dan `001` menghapus data), paket gratis Supabase tidak punya backup otomatis.

## Alur lead

Stage 1 (lead masuk, bridging, pitching) → Stage 2 (interested, menunggu arahan) → Stage 3 (kanban:
jadwal pemetaan → hasil pemetaan → pembayaran seat-lock → Closing Seat Lock; jalur keluar: Jalur Akselerasi,
Cold Leads, Failed). Definisi status ada di `src/lib/prd-stages.ts`.

Entitas (HNZ / KFI) ditentukan dari campaign: pengaturan di Settings → Campaign
(`campaign_entity_overrides`), dan bila belum diatur, ditebak dari kata "driver" pada nama campaign.
