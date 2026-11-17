-- BASELINE skema `public` produksi, diambil dari pg_dump 2026-11-17 (schema-only, tanpa data).
--
-- Ini SUMBER KEBENARAN skema saat ini. File di db/schema/ adalah riwayat dan TIDAK lengkap
-- (lihat db/README.md). Untuk membangun database baru (mis. pindah ke VPS), pakai file ini,
-- bukan db/schema/.
--
-- Yang TIDAK ada di sini (bukan bagian schema public):
--   * schema `auth` (akun login) dan trigger `on_auth_user_created` pada auth.users yang memanggil
--     public.handle_new_user(). Di Supabase ia dibuat oleh db/schema/001; saat memindahkan database,
--     bawa juga schema `auth` atau buat ulang trigger itu.
--   * GRANT / hak akses (dibuang dengan --no-privileges). Supabase menambahkannya otomatis.
--
-- Dihasilkan dengan:
--   pg_restore --schema-only --no-owner --no-privileges -f baseline.sql crm-backup-2026-11-17.dump
--
--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.12 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: campaign_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.campaign_type AS ENUM (
    'webinar',
    'ads_ig',
    'ads_fb',
    'organic',
    'event'
);


--
-- Name: conversion_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.conversion_type AS ENUM (
    'pemetaan',
    'full_payment',
    'dp',
    'webinar_attend'
);


--
-- Name: fu_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fu_type AS ENUM (
    'd1',
    'd3',
    'd7',
    'd14',
    'fu1',
    'fu2',
    'fu3',
    'fu4',
    'custom'
);


--
-- Name: lead_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lead_source AS ENUM (
    'ig',
    'fb',
    'linkedin',
    'webinar',
    'manual',
    'referral',
    'other'
);


--
-- Name: lead_stage; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lead_stage AS ENUM (
    'new',
    'probing',
    'hot',
    'potential',
    'converted',
    'rejected'
);


--
-- Name: lead_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lead_type AS ENUM (
    'inbound',
    'outbound'
);


--
-- Name: message_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_status AS ENUM (
    'connected',
    'not_connected',
    'no_response',
    'restricted',
    'pending'
);


--
-- Name: playbook_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.playbook_category AS ENUM (
    'script',
    'objection',
    'product',
    'sop',
    'faq'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'admin',
    'cro',
    'manager'
);


--
-- Name: apply_needs_action_fast(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_needs_action_fast(p_lead_id uuid, p_action_type text, p_input_val text DEFAULT NULL::text, p_input_val2 text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  actor_id uuid := auth.uid();
  next_status text;
  activity_desc text;
  expert_id uuid;
begin
  if p_lead_id is null then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Lead ID wajib diisi.');
  end if;

  if not exists (select 1 from public.leads where id = p_lead_id) then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'message', 'Lead tidak ditemukan.');
  end if;

  if coalesce(trim(p_action_type), '') = '' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Action type wajib diisi.');
  end if;

  next_status := null;
  activity_desc := null;

  if p_action_type = 'set_waiting_result' then
    next_status := 'Waiting Result';
    activity_desc := 'Lead moved to Waiting Result via Needs Action dashboard';

    if not exists (select 1 from public.pemetaan where lead_id = p_lead_id) then
      insert into public.pemetaan (lead_id, form_status, result_status)
      values (p_lead_id, 'not_sent', 'waiting');
    else
      update public.pemetaan
      set result_status = 'waiting', updated_at = now()
      where lead_id = p_lead_id;
    end if;

  elsif p_action_type = 'send_result' then
    next_status := 'Sent Result Pemetaan';
    activity_desc := 'Hasil Pemetaan dikirim: ' || coalesce(nullif(p_input_val, ''), 'Sukses');

    if not exists (select 1 from public.pemetaan where lead_id = p_lead_id) then
      insert into public.pemetaan (
        lead_id, form_status, result_status, result_ready_at, completed_at, result_notes
      )
      values (
        p_lead_id, 'submitted', 'ready', now(), now(), nullif(p_input_val, '')
      );
    else
      update public.pemetaan
      set
        result_status = 'ready',
        result_ready_at = now(),
        completed_at = now(),
        result_notes = nullif(p_input_val, ''),
        updated_at = now()
      where lead_id = p_lead_id;
    end if;

  elsif p_action_type = 'schedule_expert' then
    if coalesce(trim(p_input_val), '') = '' or coalesce(trim(p_input_val2), '') = '' then
      return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Jadwal dan nama expert wajib diisi.');
    end if;

    next_status := 'Expert Consultation Scheduled';
    activity_desc := 'Expert consultation scheduled for ' || p_input_val || ' with expert: ' || p_input_val2;

    select id into expert_id
    from public.expert_consultations
    where lead_id = p_lead_id
    limit 1;

    if expert_id is null then
      insert into public.expert_consultations (lead_id, scheduled_at, expert_name)
      values (p_lead_id, p_input_val::timestamptz, p_input_val2);
    else
      update public.expert_consultations
      set
        scheduled_at = p_input_val::timestamptz,
        expert_name = p_input_val2,
        updated_at = now()
      where id = expert_id;
    end if;

  elsif p_action_type = 'offer_seat_lock' then
    next_status := 'Seat Lock Offered';
    activity_desc := 'Seat Lock Offered';

  elsif p_action_type = 'pay_seat_lock' then
    if coalesce(trim(p_input_val), '') = '' then
      return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Nominal seat lock wajib diisi.');
    end if;

    next_status := 'Seat Lock Paid';
    activity_desc := 'Seat lock paid: Rp ' || to_char(p_input_val::numeric, 'FM999,999,999') || ' (' || coalesce(p_input_val2, '-') || ')';

    insert into public.payments (
      lead_id,
      payment_type,
      amount,
      payment_method,
      payment_date,
      verification_status,
      verified_at,
      verified_by,
      notes
    )
    values (
      p_lead_id,
      'seat_lock',
      p_input_val::numeric,
      'Transfer',
      current_date,
      'verified',
      now(),
      actor_id,
      'Verified on Seat Lock Paid Action: ' || coalesce(p_input_val2, '-')
    );

  else
    return jsonb_build_object('ok', false, 'code', 'INVALID_ACTION', 'message', 'Action type tidak dikenal: ' || p_action_type);
  end if;

  if next_status is not null then
    update public.leads
    set
      current_status = next_status,
      updated_by = actor_id,
      updated_at = now()
    where id = p_lead_id;

    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (p_lead_id, 'Status changed', activity_desc, actor_id);
  end if;

  return jsonb_build_object(
    'ok', true,
    'lead_id', p_lead_id,
    'next_status', next_status
  );
exception
  when others then
    return jsonb_build_object(
      'ok', false,
      'code', 'SAVE_FAILED',
      'message', SQLERRM
    );
end;
$$;


--
-- Name: auto_schedule_followups(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auto_schedule_followups() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Only schedule if inbound_date is set
  IF NEW.inbound_date IS NOT NULL AND TG_OP = 'INSERT' THEN
    INSERT INTO public.follow_ups (lead_id, fu_type, scheduled_date, pic_id)
    VALUES
      (NEW.id, 'd1',  (NEW.inbound_date::DATE + 1),  NEW.pic_id),
      (NEW.id, 'd3',  (NEW.inbound_date::DATE + 3),  NEW.pic_id),
      (NEW.id, 'd7',  (NEW.inbound_date::DATE + 7),  NEW.pic_id),
      (NEW.id, 'd14', (NEW.inbound_date::DATE + 14), NEW.pic_id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: check_duplicate_phone(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_duplicate_phone() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  existing_id UUID;
BEGIN
  SELECT id INTO existing_id
  FROM public.leads
  WHERE phone_number = NEW.phone_number AND id != NEW.id
  LIMIT 1;

  IF existing_id IS NOT NULL THEN
    NEW.is_duplicate := TRUE;
    NEW.duplicate_of := existing_id;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: create_lead_fast(text, text, text, text, text, text, uuid, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_lead_fast(p_full_name text, p_whatsapp_number text, p_email text DEFAULT NULL::text, p_source_campaign text DEFAULT NULL::text, p_lead_type text DEFAULT 'inbound'::text, p_current_status text DEFAULT 'New Lead'::text, p_assigned_cro_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text, p_lead_entry_date timestamp with time zone DEFAULT now()) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  actor_id uuid := auth.uid();
  clean_phone text := public.normalize_whatsapp(p_whatsapp_number);
  duplicate_record public.leads%rowtype;
  inserted_lead_id uuid;
begin
  if char_length(clean_phone) < 9 or char_length(clean_phone) > 15 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE', 'message', 'Nomor WhatsApp tidak valid.');
  end if;

  select *
  into duplicate_record
  from public.leads
  where whatsapp_normalized = clean_phone
    and duplicate_of is null
  limit 1;

  if found then
    return jsonb_build_object(
      'ok', false,
      'code', 'DUPLICATE_PHONE',
      'message', 'Nomor WhatsApp ini sudah terdaftar.',
      'duplicate_lead', jsonb_build_object(
        'id', duplicate_record.id,
        'full_name', duplicate_record.full_name,
        'source_campaign', duplicate_record.source_campaign,
        'current_status', duplicate_record.current_status
      )
    );
  end if;

  insert into public.leads (
    full_name,
    whatsapp_number,
    whatsapp_normalized,
    email,
    source_campaign,
    lead_type,
    current_status,
    assigned_cro_id,
    notes,
    lead_entry_date,
    created_by,
    updated_by
  )
  values (
    p_full_name,
    clean_phone,
    clean_phone,
    nullif(p_email, ''),
    p_source_campaign,
    coalesce(nullif(p_lead_type, ''), 'inbound'),
    coalesce(nullif(p_current_status, ''), 'New Lead'),
    p_assigned_cro_id,
    nullif(p_notes, ''),
    coalesce(p_lead_entry_date, now()),
    actor_id,
    actor_id
  )
  returning id into inserted_lead_id;

  insert into public.pemetaan (lead_id, form_status, result_status)
  values (inserted_lead_id, 'not_sent', 'not_ready');

  insert into public.lead_activities (lead_id, activity_type, description, created_by)
  values (inserted_lead_id, 'Lead created', 'Lead created manually via Tambah Lead form', actor_id);

  return jsonb_build_object('ok', true, 'id', inserted_lead_id);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'code', 'DUPLICATE_PHONE', 'message', 'Nomor WhatsApp ini sudah terdaftar.');
end;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.users (id, name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email, 'User'),
    NEW.email,
    'cro'
  );
  RETURN NEW;
END;
$$;


--
-- Name: normalize_whatsapp(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_whatsapp(value text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  clean_phone text;
begin
  clean_phone := regexp_replace(coalesce(value, ''), '\D', '', 'g');

  if clean_phone like '0%' then
    clean_phone := '62' || substring(clean_phone from 2);
  elsif clean_phone like '8%' then
    clean_phone := '62' || clean_phone;
  end if;

  return clean_phone;
end;
$$;


--
-- Name: save_work_queue_fast(uuid, text, text, text, text, text, boolean, text, text, text, text, date, text, text, text, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_work_queue_fast(p_lead_id uuid, p_current_status text, p_next_status text, p_lead_condition text, p_objection_category text, p_solution_given text, p_expert_needed boolean DEFAULT false, p_expert_type text DEFAULT NULL::text, p_commercial_type text DEFAULT 'Free'::text, p_service_opportunity text DEFAULT NULL::text, p_next_action text DEFAULT NULL::text, p_next_follow_up_date date DEFAULT NULL::date, p_result text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_funnel_notes text DEFAULT NULL::text, p_follow_up_id uuid DEFAULT NULL::uuid, p_complete_follow_up boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  actor_id uuid := auth.uid();
  intervention_id uuid;
  activity_desc text;
  fu_done_result text;
begin
  if p_lead_id is null then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Lead ID wajib diisi.');
  end if;

  if not exists (select 1 from public.leads where id = p_lead_id) then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'message', 'Lead tidak ditemukan.');
  end if;

  if coalesce(trim(p_lead_condition), '') = ''
     or coalesce(trim(p_objection_category), '') = ''
     or coalesce(trim(p_solution_given), '') = ''
     or coalesce(trim(p_next_action), '') = '' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Kondisi lead, objection, solusi, dan next action wajib diisi.');
  end if;

  insert into public.lead_interventions (
    lead_id,
    created_by,
    lead_condition,
    objection_category,
    solution_given,
    expert_needed,
    expert_type,
    commercial_type,
    service_opportunity,
    next_action,
    next_follow_up_date,
    result,
    notes
  )
  values (
    p_lead_id,
    actor_id,
    p_lead_condition,
    p_objection_category,
    p_solution_given,
    coalesce(p_expert_needed, false),
    case when coalesce(p_expert_needed, false) then nullif(p_expert_type, '') else null end,
    coalesce(nullif(p_commercial_type, ''), 'Free'),
    nullif(p_service_opportunity, ''),
    p_next_action,
    p_next_follow_up_date,
    nullif(p_result, ''),
    nullif(p_notes, '')
  )
  returning id into intervention_id;

  update public.leads
  set
    current_status = coalesce(nullif(p_next_status, ''), current_status),
    lead_segment = p_objection_category,
    next_action = p_next_action,
    next_follow_up_date = p_next_follow_up_date,
    funnel_notes = coalesce(nullif(p_funnel_notes, ''), funnel_notes),
    last_contacted_date = now(),
    updated_by = actor_id,
    updated_at = now()
  where id = p_lead_id;

  activity_desc := p_lead_condition || ' | Objection: ' || p_objection_category || ' | Solusi: ' || p_solution_given;

  insert into public.lead_activities (lead_id, activity_type, description, created_by)
  values (p_lead_id, 'Intervention Logged', activity_desc, actor_id);

  if coalesce(p_current_status, '') <> coalesce(p_next_status, '') then
    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (
      p_lead_id,
      'Status changed',
      p_current_status || ' -> ' || p_next_status || ' via Work Queue',
      actor_id
    );
  end if;

  if p_next_follow_up_date is not null then
    insert into public.follow_ups (
      lead_id,
      scheduled_date,
      fu_type,
      notes,
      pic_id
    )
    values (
      p_lead_id,
      p_next_follow_up_date,
      'whatsapp',
      coalesce(nullif(p_notes, ''), nullif(p_result, ''), 'Next action: ' || p_next_action),
      actor_id
    );
  end if;

  if p_follow_up_id is not null and coalesce(p_complete_follow_up, false) then
    fu_done_result := coalesce(nullif(p_result, ''), nullif(p_notes, ''), 'Selesai via Work Queue');

    update public.follow_ups
    set
      is_done = true,
      done_at = now(),
      result = fu_done_result,
      updated_at = now()
    where id = p_follow_up_id
      and lead_id = p_lead_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'lead_id', p_lead_id,
    'intervention_id', intervention_id
  );
exception
  when others then
    return jsonb_build_object(
      'ok', false,
      'code', 'SAVE_FAILED',
      'message', SQLERRM
    );
end;
$$;


--
-- Name: save_work_queue_fast(uuid, text, text, text, text, text, boolean, text, text, text, text, date, text, text, text, uuid, boolean, boolean, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_work_queue_fast(p_lead_id uuid, p_current_status text, p_next_status text, p_lead_condition text, p_objection_category text, p_solution_given text, p_expert_needed boolean DEFAULT false, p_expert_type text DEFAULT NULL::text, p_commercial_type text DEFAULT 'Free'::text, p_service_opportunity text DEFAULT NULL::text, p_next_action text DEFAULT NULL::text, p_next_follow_up_date date DEFAULT NULL::date, p_result text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_funnel_notes text DEFAULT NULL::text, p_follow_up_id uuid DEFAULT NULL::uuid, p_complete_follow_up boolean DEFAULT false, p_close_lead boolean DEFAULT false, p_lost_status text DEFAULT NULL::text, p_lost_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  actor_id uuid := auth.uid();
  intervention_id uuid;
  activity_desc text;
  fu_done_result text;
  resolved_next_status text;
begin
  if p_lead_id is null then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Lead ID wajib diisi.');
  end if;

  if not exists (select 1 from public.leads where id = p_lead_id) then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'message', 'Lead tidak ditemukan.');
  end if;

  if coalesce(trim(p_lead_condition), '') = ''
     or coalesce(trim(p_objection_category), '') = ''
     or coalesce(trim(p_solution_given), '') = '' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Kondisi lead, objection, dan solusi wajib diisi.');
  end if;

  if coalesce(p_close_lead, false) then
    if coalesce(trim(p_lost_status), '') not in ('Not Interested', 'Not Eligible') then
      return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Status tutup lead harus Not Interested atau Not Eligible.');
    end if;

    if coalesce(trim(p_lost_reason), '') = '' then
      return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Alasan lost wajib diisi saat menutup lead.');
    end if;
  elsif coalesce(trim(p_next_action), '') = '' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT', 'message', 'Kondisi lead, objection, solusi, dan next action wajib diisi.');
  end if;

  insert into public.lead_interventions (
    lead_id,
    created_by,
    lead_condition,
    objection_category,
    solution_given,
    expert_needed,
    expert_type,
    commercial_type,
    service_opportunity,
    next_action,
    next_follow_up_date,
    result,
    notes
  )
  values (
    p_lead_id,
    actor_id,
    p_lead_condition,
    p_objection_category,
    p_solution_given,
    case when coalesce(p_close_lead, false) then false else coalesce(p_expert_needed, false) end,
    case when coalesce(p_close_lead, false) then null when coalesce(p_expert_needed, false) then nullif(p_expert_type, '') else null end,
    coalesce(nullif(p_commercial_type, ''), 'Free'),
    nullif(p_service_opportunity, ''),
    case when coalesce(p_close_lead, false) then 'Tutup Lead' else p_next_action end,
    case when coalesce(p_close_lead, false) then null else p_next_follow_up_date end,
    nullif(p_result, ''),
    nullif(p_notes, '')
  )
  returning id into intervention_id;

  resolved_next_status := case
    when coalesce(p_close_lead, false) then p_lost_status
    else coalesce(nullif(p_next_status, ''), p_current_status)
  end;

  update public.leads
  set
    current_status = resolved_next_status,
    lost_reason = case when coalesce(p_close_lead, false) then nullif(p_lost_reason, '') else lost_reason end,
    lead_segment = p_objection_category,
    next_action = case when coalesce(p_close_lead, false) then null else p_next_action end,
    next_follow_up_date = case when coalesce(p_close_lead, false) then null else p_next_follow_up_date end,
    funnel_notes = coalesce(nullif(p_funnel_notes, ''), funnel_notes),
    last_contacted_date = now(),
    updated_by = actor_id,
    updated_at = now()
  where id = p_lead_id;

  activity_desc := p_lead_condition || ' | Objection: ' || p_objection_category || ' | Solusi: ' || p_solution_given;

  insert into public.lead_activities (lead_id, activity_type, description, created_by)
  values (p_lead_id, 'Intervention Logged', activity_desc, actor_id);

  if coalesce(p_current_status, '') <> coalesce(resolved_next_status, '') then
    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (
      p_lead_id,
      'Status changed',
      p_current_status || ' -> ' || resolved_next_status || case when coalesce(p_close_lead, false) then ' (tutup lead)' else ' via Work Queue' end,
      actor_id
    );
  end if;

  if coalesce(p_close_lead, false) then
    update public.follow_ups
    set
      is_done = true,
      done_at = now(),
      result = coalesce(nullif(p_result, ''), 'Lead ditutup: ' || p_lost_status),
      updated_at = now()
    where lead_id = p_lead_id
      and is_done = false;

    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (
      p_lead_id,
      'Lead Closed',
      resolved_next_status || ' — ' || p_lost_reason,
      actor_id
    );
  else
    if p_next_follow_up_date is not null then
      insert into public.follow_ups (
        lead_id,
        scheduled_date,
        fu_type,
        notes,
        pic_id
      )
      values (
        p_lead_id,
        p_next_follow_up_date,
        'whatsapp',
        coalesce(nullif(p_notes, ''), nullif(p_result, ''), 'Next action: ' || p_next_action),
        actor_id
      );
    end if;
  end if;

  if p_follow_up_id is not null and coalesce(p_complete_follow_up, false) then
    fu_done_result := coalesce(nullif(p_result, ''), nullif(p_notes, ''), 'Selesai via Work Queue');

    update public.follow_ups
    set
      is_done = true,
      done_at = now(),
      result = fu_done_result,
      updated_at = now()
    where id = p_follow_up_id
      and lead_id = p_lead_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'lead_id', p_lead_id,
    'intervention_id', intervention_id,
    'closed', coalesce(p_close_lead, false)
  );
exception
  when others then
    return jsonb_build_object(
      'ok', false,
      'code', 'SAVE_FAILED',
      'message', SQLERRM
    );
end;
$$;


--
-- Name: update_lead_core_fast(uuid, text, text, text, text, text, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_lead_core_fast(p_lead_id uuid, p_full_name text, p_whatsapp_number text, p_email text DEFAULT NULL::text, p_source_campaign text DEFAULT NULL::text, p_current_status text DEFAULT 'New Lead'::text, p_assigned_cro_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text, p_lost_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  actor_id uuid := auth.uid();
  clean_phone text := public.normalize_whatsapp(p_whatsapp_number);
  duplicate_record public.leads%rowtype;
  old_status text;
begin
  if char_length(clean_phone) < 9 or char_length(clean_phone) > 15 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE', 'message', 'Nomor WhatsApp tidak valid.');
  end if;

  select *
  into duplicate_record
  from public.leads
  where whatsapp_normalized = clean_phone
    and duplicate_of is null
    and id <> p_lead_id
  limit 1;

  if found then
    return jsonb_build_object(
      'ok', false,
      'code', 'DUPLICATE_PHONE',
      'message', 'Nomor WhatsApp ini sudah terdaftar.',
      'duplicate_lead', jsonb_build_object(
        'id', duplicate_record.id,
        'full_name', duplicate_record.full_name,
        'source_campaign', duplicate_record.source_campaign,
        'current_status', duplicate_record.current_status
      )
    );
  end if;

  select current_status
  into old_status
  from public.leads
  where id = p_lead_id;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'message', 'Lead tidak ditemukan.');
  end if;

  update public.leads
  set
    full_name = p_full_name,
    whatsapp_number = clean_phone,
    whatsapp_normalized = clean_phone,
    email = nullif(p_email, ''),
    source_campaign = p_source_campaign,
    current_status = coalesce(nullif(p_current_status, ''), 'New Lead'),
    assigned_cro_id = p_assigned_cro_id,
    notes = nullif(p_notes, ''),
    lost_reason = nullif(p_lost_reason, ''),
    updated_by = actor_id,
    updated_at = now()
  where id = p_lead_id;

  if old_status <> coalesce(nullif(p_current_status, ''), 'New Lead') then
    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (p_lead_id, 'Status changed', 'Status changed from ' || old_status || ' to ' || coalesce(nullif(p_current_status, ''), 'New Lead') || ' via manual edit', actor_id);
  else
    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (p_lead_id, 'Lead Updated', 'Core lead information updated manually', actor_id);
  end if;

  return jsonb_build_object('ok', true, 'id', p_lead_id);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'code', 'DUPLICATE_PHONE', 'message', 'Nomor WhatsApp ini sudah terdaftar.');
end;
$$;


--
-- Name: update_lead_core_fast(uuid, text, text, text, text, text, uuid, text, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_lead_core_fast(p_lead_id uuid, p_full_name text, p_whatsapp_number text, p_email text DEFAULT NULL::text, p_source_campaign text DEFAULT NULL::text, p_current_status text DEFAULT 'New Lead'::text, p_assigned_cro_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text, p_lost_reason text DEFAULT NULL::text, p_lead_entry_date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  return public.update_lead_core_fast_v2(
    p_lead_id,
    p_full_name,
    p_whatsapp_number,
    p_email,
    p_source_campaign,
    p_current_status,
    p_assigned_cro_id,
    p_notes,
    p_lost_reason,
    p_lead_entry_date
  );
end;
$$;


--
-- Name: update_lead_core_fast_v2(uuid, text, text, text, text, text, uuid, text, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_lead_core_fast_v2(p_lead_id uuid, p_full_name text, p_whatsapp_number text, p_email text DEFAULT NULL::text, p_source_campaign text DEFAULT NULL::text, p_current_status text DEFAULT 'New Lead'::text, p_assigned_cro_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text, p_lost_reason text DEFAULT NULL::text, p_lead_entry_date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  actor_id uuid := auth.uid();
  clean_phone text := public.normalize_whatsapp(p_whatsapp_number);
  duplicate_record public.leads%rowtype;
  old_status text;
begin
  if char_length(clean_phone) < 9 or char_length(clean_phone) > 15 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE', 'message', 'Nomor WhatsApp tidak valid.');
  end if;

  select *
  into duplicate_record
  from public.leads
  where whatsapp_normalized = clean_phone
    and duplicate_of is null
    and id <> p_lead_id
  limit 1;

  if found then
    return jsonb_build_object(
      'ok', false,
      'code', 'DUPLICATE_PHONE',
      'message', 'Nomor WhatsApp ini sudah terdaftar.',
      'duplicate_lead', jsonb_build_object(
        'id', duplicate_record.id,
        'full_name', duplicate_record.full_name,
        'source_campaign', duplicate_record.source_campaign,
        'current_status', duplicate_record.current_status
      )
    );
  end if;

  select current_status
  into old_status
  from public.leads
  where id = p_lead_id;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'message', 'Lead tidak ditemukan.');
  end if;

  update public.leads
  set
    full_name = p_full_name,
    whatsapp_number = clean_phone,
    whatsapp_normalized = clean_phone,
    email = nullif(p_email, ''),
    source_campaign = p_source_campaign,
    current_status = coalesce(nullif(p_current_status, ''), 'New Lead'),
    assigned_cro_id = p_assigned_cro_id,
    notes = nullif(p_notes, ''),
    lost_reason = nullif(p_lost_reason, ''),
    lead_entry_date = coalesce(p_lead_entry_date, lead_entry_date),
    updated_by = actor_id,
    updated_at = now()
  where id = p_lead_id;

  if old_status <> coalesce(nullif(p_current_status, ''), 'New Lead') then
    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (
      p_lead_id,
      'Status changed',
      'Status changed from ' || old_status || ' to ' || coalesce(nullif(p_current_status, ''), 'New Lead') || ' via manual edit',
      actor_id
    );
  else
    insert into public.lead_activities (lead_id, activity_type, description, created_by)
    values (p_lead_id, 'Lead Updated', 'Core lead information updated manually', actor_id);
  end if;

  return jsonb_build_object('ok', true, 'id', p_lead_id);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'code', 'DUPLICATE_PHONE', 'message', 'Nomor WhatsApp ini sudah terdaftar.');
end;
$$;


--
-- Name: update_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


--
-- Name: batch_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_targets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_name text NOT NULL,
    target_seat_lock integer NOT NULL,
    start_date date NOT NULL,
    closing_date date NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: campaign_entity_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_entity_overrides (
    source_campaign text NOT NULL,
    entity text NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campaign_entity_overrides_entity_check CHECK ((entity = ANY (ARRAY['HNZ'::text, 'KFI'::text])))
);


--
-- Name: danacita_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.danacita_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    flow text NOT NULL,
    label text NOT NULL,
    status text DEFAULT 'sedang_ditinjau'::text NOT NULL,
    status_reason text,
    last_status_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT danacita_applications_flow_check CHECK ((flow = ANY (ARRAY['hot'::text, 'cold'::text]))),
    CONSTRAINT danacita_applications_label_check CHECK ((label = ANY (ARRAY['pendidikan'::text, 'keberangkatan'::text, 'pendidikan_keberangkatan'::text]))),
    CONSTRAINT danacita_applications_status_check CHECK ((status = ANY (ARRAY['sedang_ditinjau'::text, 'tidak_eligible'::text, 'berhasil'::text, 'lainnya'::text])))
);


--
-- Name: expert_consultations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expert_consultations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    expert_name text,
    scheduled_at timestamp with time zone,
    completed_at timestamp with time zone,
    consultation_result text,
    recommendation text,
    next_step text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: follow_ups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.follow_ups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    pic_id uuid,
    scheduled_date date NOT NULL,
    fu_type text DEFAULT 'chat'::text NOT NULL,
    notes text,
    is_done boolean DEFAULT false NOT NULL,
    done_at timestamp with time zone,
    result text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: lead_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lead_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    activity_type text NOT NULL,
    description text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: lead_interventions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lead_interventions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    created_by uuid,
    lead_condition text,
    objection_category text,
    solution_given text,
    expert_needed boolean DEFAULT false NOT NULL,
    expert_type text,
    commercial_type text,
    service_opportunity text,
    next_action text,
    next_follow_up_date date,
    result text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: leads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    full_name text NOT NULL,
    whatsapp_number text NOT NULL,
    email text,
    source_campaign text NOT NULL,
    assigned_cro_id uuid,
    current_status text DEFAULT 'New Lead'::text NOT NULL,
    lead_entry_date timestamp with time zone DEFAULT now() NOT NULL,
    last_contacted_date timestamp with time zone,
    follow_up_result text,
    notes text,
    lost_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    lead_type text DEFAULT 'inbound'::text NOT NULL,
    created_by uuid,
    updated_by uuid,
    duplicate_of uuid,
    duplicate_reason text,
    whatsapp_normalized text,
    lead_quality text,
    lead_segment text,
    entry_channel text,
    next_action text,
    next_follow_up_date date,
    funnel_notes text,
    legacy_status text
);


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    payment_type text NOT NULL,
    amount numeric NOT NULL,
    payment_method text NOT NULL,
    payment_date date NOT NULL,
    proof_url text,
    verification_status text DEFAULT 'pending'::text NOT NULL,
    verified_by uuid,
    verified_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payments_payment_method_check CHECK ((payment_method = ANY (ARRAY['web'::text, 'danacita'::text, 'manual'::text])))
);


--
-- Name: pemetaan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pemetaan (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    form_status text DEFAULT 'not_sent'::text NOT NULL,
    scheduled_at timestamp with time zone,
    completed_at timestamp with time zone,
    result_status text DEFAULT 'not_ready'::text NOT NULL,
    result_ready_at timestamp with time zone,
    result_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: playbook_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playbook_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category text DEFAULT 'script'::text NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    tags text[] DEFAULT '{}'::text[],
    is_active boolean DEFAULT true NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    password_hash text,
    role text DEFAULT 'cro'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: batch_targets batch_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_targets
    ADD CONSTRAINT batch_targets_pkey PRIMARY KEY (id);


--
-- Name: campaign_entity_overrides campaign_entity_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_entity_overrides
    ADD CONSTRAINT campaign_entity_overrides_pkey PRIMARY KEY (source_campaign);


--
-- Name: danacita_applications danacita_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danacita_applications
    ADD CONSTRAINT danacita_applications_pkey PRIMARY KEY (id);


--
-- Name: expert_consultations expert_consultations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expert_consultations
    ADD CONSTRAINT expert_consultations_pkey PRIMARY KEY (id);


--
-- Name: follow_ups follow_ups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follow_ups
    ADD CONSTRAINT follow_ups_pkey PRIMARY KEY (id);


--
-- Name: lead_activities lead_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lead_activities
    ADD CONSTRAINT lead_activities_pkey PRIMARY KEY (id);


--
-- Name: lead_interventions lead_interventions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lead_interventions
    ADD CONSTRAINT lead_interventions_pkey PRIMARY KEY (id);


--
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: pemetaan pemetaan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pemetaan
    ADD CONSTRAINT pemetaan_pkey PRIMARY KEY (id);


--
-- Name: playbook_items playbook_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbook_items
    ADD CONSTRAINT playbook_items_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: danacita_applications_lead_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX danacita_applications_lead_id_idx ON public.danacita_applications USING btree (lead_id);


--
-- Name: idx_leads_legacy_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_leads_legacy_status ON public.leads USING btree (legacy_status);


--
-- Name: lead_interventions_commercial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lead_interventions_commercial_idx ON public.lead_interventions USING btree (commercial_type);


--
-- Name: lead_interventions_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lead_interventions_created_at_idx ON public.lead_interventions USING btree (created_at);


--
-- Name: lead_interventions_created_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lead_interventions_created_by_idx ON public.lead_interventions USING btree (created_by);


--
-- Name: lead_interventions_lead_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lead_interventions_lead_id_idx ON public.lead_interventions USING btree (lead_id);


--
-- Name: lead_interventions_objection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lead_interventions_objection_idx ON public.lead_interventions USING btree (objection_category);


--
-- Name: leads_lead_quality_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leads_lead_quality_idx ON public.leads USING btree (lead_quality);


--
-- Name: leads_lead_segment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leads_lead_segment_idx ON public.leads USING btree (lead_segment);


--
-- Name: leads_next_follow_up_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leads_next_follow_up_date_idx ON public.leads USING btree (next_follow_up_date);


--
-- Name: leads_whatsapp_normalized_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX leads_whatsapp_normalized_unique ON public.leads USING btree (whatsapp_normalized) WHERE (duplicate_of IS NULL);


--
-- Name: batch_targets trg_batch_targets_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_batch_targets_updated_at BEFORE UPDATE ON public.batch_targets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: expert_consultations trg_expert_consultations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_expert_consultations_updated_at BEFORE UPDATE ON public.expert_consultations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: follow_ups trg_follow_ups_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_follow_ups_updated_at BEFORE UPDATE ON public.follow_ups FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: leads trg_leads_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_leads_updated_at BEFORE UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: payments trg_payments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: pemetaan trg_pemetaan_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pemetaan_updated_at BEFORE UPDATE ON public.pemetaan FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: playbook_items trg_playbook_items_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_playbook_items_updated_at BEFORE UPDATE ON public.playbook_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: campaign_entity_overrides campaign_entity_overrides_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_entity_overrides
    ADD CONSTRAINT campaign_entity_overrides_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: danacita_applications danacita_applications_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danacita_applications
    ADD CONSTRAINT danacita_applications_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: danacita_applications danacita_applications_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danacita_applications
    ADD CONSTRAINT danacita_applications_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: danacita_applications danacita_applications_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danacita_applications
    ADD CONSTRAINT danacita_applications_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: expert_consultations expert_consultations_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expert_consultations
    ADD CONSTRAINT expert_consultations_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: follow_ups follow_ups_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follow_ups
    ADD CONSTRAINT follow_ups_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: follow_ups follow_ups_pic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follow_ups
    ADD CONSTRAINT follow_ups_pic_id_fkey FOREIGN KEY (pic_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lead_activities lead_activities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lead_activities
    ADD CONSTRAINT lead_activities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lead_activities lead_activities_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lead_activities
    ADD CONSTRAINT lead_activities_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: lead_interventions lead_interventions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lead_interventions
    ADD CONSTRAINT lead_interventions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lead_interventions lead_interventions_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lead_interventions
    ADD CONSTRAINT lead_interventions_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: leads leads_assigned_cro_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_assigned_cro_id_fkey FOREIGN KEY (assigned_cro_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: leads leads_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: leads leads_duplicate_of_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_duplicate_of_fkey FOREIGN KEY (duplicate_of) REFERENCES public.leads(id);


--
-- Name: leads leads_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: payments payments_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: payments payments_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: pemetaan pemetaan_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pemetaan
    ADD CONSTRAINT pemetaan_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: playbook_items playbook_items_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbook_items
    ADD CONSTRAINT playbook_items_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: batch_targets Allow all for authenticated users on batch_targets; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on batch_targets" ON public.batch_targets TO authenticated USING (true) WITH CHECK (true);


--
-- Name: campaign_entity_overrides Allow all for authenticated users on campaign_entity_overrides; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on campaign_entity_overrides" ON public.campaign_entity_overrides TO authenticated USING (true) WITH CHECK (true);


--
-- Name: danacita_applications Allow all for authenticated users on danacita_applications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on danacita_applications" ON public.danacita_applications TO authenticated USING (true) WITH CHECK (true);


--
-- Name: expert_consultations Allow all for authenticated users on expert_consultations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on expert_consultations" ON public.expert_consultations TO authenticated USING (true) WITH CHECK (true);


--
-- Name: follow_ups Allow all for authenticated users on follow_ups; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on follow_ups" ON public.follow_ups TO authenticated USING (true) WITH CHECK (true);


--
-- Name: lead_activities Allow all for authenticated users on lead_activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on lead_activities" ON public.lead_activities TO authenticated USING (true) WITH CHECK (true);


--
-- Name: leads Allow all for authenticated users on leads; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on leads" ON public.leads TO authenticated USING (true) WITH CHECK (true);


--
-- Name: payments Allow all for authenticated users on payments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on payments" ON public.payments TO authenticated USING (true) WITH CHECK (true);


--
-- Name: pemetaan Allow all for authenticated users on pemetaan; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on pemetaan" ON public.pemetaan TO authenticated USING (true) WITH CHECK (true);


--
-- Name: playbook_items Allow all for authenticated users on playbook_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on playbook_items" ON public.playbook_items TO authenticated USING (true) WITH CHECK (true);


--
-- Name: users Allow all for authenticated users on users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated users on users" ON public.users TO authenticated USING (true) WITH CHECK (true);


--
-- Name: batch_targets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.batch_targets ENABLE ROW LEVEL SECURITY;

--
-- Name: campaign_entity_overrides; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.campaign_entity_overrides ENABLE ROW LEVEL SECURITY;

--
-- Name: danacita_applications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.danacita_applications ENABLE ROW LEVEL SECURITY;

--
-- Name: expert_consultations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expert_consultations ENABLE ROW LEVEL SECURITY;

--
-- Name: follow_ups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.follow_ups ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_interventions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_interventions ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_interventions lead_interventions_delete_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lead_interventions_delete_authenticated ON public.lead_interventions FOR DELETE TO authenticated USING (true);


--
-- Name: lead_interventions lead_interventions_insert_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lead_interventions_insert_authenticated ON public.lead_interventions FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: lead_interventions lead_interventions_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lead_interventions_select_authenticated ON public.lead_interventions FOR SELECT TO authenticated USING (true);


--
-- Name: lead_interventions lead_interventions_update_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lead_interventions_update_authenticated ON public.lead_interventions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: leads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

--
-- Name: payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

--
-- Name: pemetaan; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pemetaan ENABLE ROW LEVEL SECURITY;

--
-- Name: playbook_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.playbook_items ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--


