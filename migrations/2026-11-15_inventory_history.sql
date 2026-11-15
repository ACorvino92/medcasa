-- MedCasa: cronologia condivisa e tracciabilità automatica.
-- Eseguire una sola volta nell'editor SQL di Supabase.
create table if not exists public.inventory_events (
  id bigint generated always as identity primary key,
  household_id uuid not null,
  medicine_id uuid,
  medicine_name text not null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  actor_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists inventory_events_household_recent
  on public.inventory_events (household_id, created_at desc, id desc);
alter table public.inventory_events enable row level security;
drop policy if exists "Members can read inventory history" on public.inventory_events;
create policy "Members can read inventory history" on public.inventory_events
for select to authenticated using (
  exists (select 1 from public.memberships m
          where m.household_id = inventory_events.household_id
          and m.user_id = (select auth.uid()))
);
grant select on public.inventory_events to authenticated;
revoke insert, update, delete on public.inventory_events from anon, authenticated;

create or replace function public.medcasa_audit_lot()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare v_med record; v_old jsonb; v_new jsonb;
begin
  select id, household_id, name into v_med from public.medicines
  where id = coalesce(new.medicine_id,old.medicine_id);
  if not found then return coalesce(new,old); end if;
  if tg_op = 'UPDATE' and
     (old.quantity,old.expiry_month,old.units_per_pack,old.remaining_units)
     is not distinct from
     (new.quantity,new.expiry_month,new.units_per_pack,new.remaining_units)
  then return new; end if;
  if tg_op <> 'INSERT' then
    v_old=jsonb_build_object('quantity',old.quantity,'expiry',old.expiry_month,
      'units_per_pack',old.units_per_pack,'remaining_units',old.remaining_units);
  end if;
  if tg_op <> 'DELETE' then
    v_new=jsonb_build_object('quantity',new.quantity,'expiry',new.expiry_month,
      'units_per_pack',new.units_per_pack,'remaining_units',new.remaining_units);
  end if;
  insert into public.inventory_events
    (household_id,medicine_id,medicine_name,event_type,details,actor_id)
  values(v_med.household_id,v_med.id,v_med.name,
    case tg_op when 'INSERT' then 'lot_added' when 'DELETE' then 'lot_deleted'
    else 'lot_updated' end,
    jsonb_build_object('before',v_old,'after',v_new),auth.uid());
  return coalesce(new,old);
end; $$;

drop trigger if exists medcasa_lot_audit on public.lots;
create trigger medcasa_lot_audit
after insert or update or delete on public.lots
for each row execute function public.medcasa_audit_lot();

create or replace function public.medcasa_audit_medicine()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' and
    (old.name,old.active_ingredient,old.strength,old.dosage_form,
     old.storage_location,old.minimum_stock) is not distinct from
    (new.name,new.active_ingredient,new.strength,new.dosage_form,
     new.storage_location,new.minimum_stock) then return new; end if;
  insert into public.inventory_events
    (household_id,medicine_id,medicine_name,event_type,details,actor_id)
  values(new.household_id,new.id,new.name,
    case when tg_op='INSERT' then 'medicine_added' else 'medicine_updated' end,
    jsonb_build_object('before',case when tg_op='UPDATE' then
      jsonb_build_object('minimum_stock',old.minimum_stock,'name',old.name)
      else null end,'after',
      jsonb_build_object('minimum_stock',new.minimum_stock,'name',new.name)),
    auth.uid());
  return new;
end; $$;
drop trigger if exists medcasa_medicine_audit on public.medicines;
create trigger medcasa_medicine_audit
after insert or update on public.medicines
for each row execute function public.medcasa_audit_medicine();
