# Keep KFI + Stage 3 Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One SQL script that backs up, then permanently deletes, every lead that is neither KFI/Driver nor in a Stage 3 status, together with its child rows.

**Architecture:** A single file with three sections run in order in the Supabase SQL editor: (1) read-only dry-run counts, (2) a backup SELECT whose result is downloaded as CSV, (3) a transaction that deletes child rows then leads, with a count guard that aborts on mismatch. Follows the pattern of `supabase-prd-v3-keep-important.sql`.

**Tech Stack:** PostgreSQL (Supabase). No application code changes.

**Spec:** `docs/superpowers/specs/2026-11-17-keep-kfi-and-stage3-design.md`

> **Catatan hasil akhir (2026-11-17):** plan ini sudah dijalankan. File yang dihasilkan bukan satu
> `supabase-prd-v3-keep-kfi-and-stage3.sql` melainkan folder `db/one-off/2026-11-17_cleanup-kfi-stage3/` (file 0–3), dengan
> tambahan tabel `danacita_applications` dan angka konfirmasi `confirmed_delete`. Lihat spec untuk alasannya.

## Global Constraints

- Keep rule is (KFI) OR (Stage 3). Delete = neither.
- KFI resolution must mirror `src/lib/entity.ts`: exact-match `campaign_entity_overrides.source_campaign = leads.source_campaign` wins and gives `entity`; otherwise KFI iff `lower(coalesce(source_campaign,'')) like '%driver%'`; otherwise HNZ.
- Stage 3 statuses (exact strings): `Menunggu jadwal pemetaan`, `Menunggu hasil pemetaan`, `Menunggu jadwal expert consultation`, `Menunggu pembayaran seat-lock`, `Jalur Akselerasi`, `Closing Seat Lock`, `Cold Leads`, `Failed`.
- Child tables deleted (all keyed by `lead_id`): `lead_activities`, `follow_ups`, `lead_interventions`, `payments`, `pemetaan`, `expert_consultations`.
- Do not modify `supabase-prd-v3-keep-important.sql` or any file under `src/`.
- Deletion is permanent; the script cannot be run by the agent (no DB access) and must be run by the user after taking a Supabase backup.

## Review Focus

- Lead with `source_campaign` NULL or empty: resolves to HNZ unless overridden, so it is deleted unless in Stage 3.
- Campaign override says HNZ for a name containing "driver": override wins, lead is not KFI (matches the app badge).
- Campaign name differing only by case or trailing whitespace from the override key: app does exact match, so the script must too.
- A deleted lead with a verified payment or pemetaan row: allowed by the spec but must be visible in the dry-run so the user decides before deleting.
- Running the script twice: second run deletes nothing and the guard must not abort.

---

### Task 1: Write the cleanup script

**Files:**
- Create: `supabase-prd-v3-keep-kfi-and-stage3.sql`

**Interfaces:**
- Consumes: tables `leads(id, source_campaign, current_status, ...)`, `campaign_entity_overrides(source_campaign, entity)`, and the six child tables above.
- Produces: no objects persist; uses a transaction-scoped temp table `_delete_ids (id uuid primary key)`.

- [ ] **Step 1: Write the header comment** stating the keep rule, the KFI resolution rule, that deletion is permanent, that sections must be run in order (1 → 2 → 3), and that a Supabase backup should be taken first.

- [ ] **Step 2: Write Section 1 (dry-run, read-only).** One query using a CTE `resolved` that returns `l.id`, `l.current_status`, and `entity` (override `entity` if present, else `KFI`/`HNZ` by the "driver" rule), plus `is_stage3` and `keep = entity = 'KFI' or is_stage3`. Output, in one result set: `total_leads`, `keep_total`, `keep_kfi_only`, `keep_stage3_only`, `keep_both`, `delete_total`, `delete_with_verified_payment`, `delete_with_pemetaan_or_expert`.

- [ ] **Step 3: Write Section 2 (backup).** A SELECT over the same CTE returning all `leads` columns for `keep = false`, plus `entity` and per-lead counts of each child table, ordered by `created_at`. Comment: download the result as CSV from the SQL editor and hand it to the client before running Section 3.

- [ ] **Step 4: Write Section 3 (delete).** In `begin; ... commit;`: create `_delete_ids` (`on commit drop`) filled from the same CTE with `keep = false`; a `do $$` block that records `count(*)` of `_delete_ids`; delete from the six child tables where `lead_id in (select id from _delete_ids)`; `delete from leads where id in (select id from _delete_ids)` capturing `get diagnostics` row count; `raise exception` if deleted count <> recorded count; then a final `select count(*) as remaining_leads from leads`.

- [ ] **Step 5: Verify syntax locally.** If `psql`/`postgres` is available, load a scratch DB with `migration.sql`, `supabase-campaign-entity-overrides.sql`, `supabase-lead-interventions.sql`, seed leads covering each Review Focus case, and run Sections 1–3, checking counts. If no local Postgres is available, state that explicitly and rely on the dry-run in Step 6.
  Expected: Section 1 counts match the seed; after Section 3 only KFI and Stage 3 leads remain; a second run of Section 3 deletes 0 rows without error.

- [ ] **Step 6: Hand off to the user** with instructions: take Supabase backup → run Section 1 and compare `keep_total` against expectations (Stage 3 board shows 101) → run Section 2 and download CSV → run Section 3.

- [ ] **Step 7: Commit** (only if the user asks; this repo's rule is to commit on request).
