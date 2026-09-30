-- =====================================================================
--  Agnipeak PMS — v4 UPGRADE  (run once in Supabase → SQL Editor)
--  Safe to run again. Does NOT delete any production data.
--  1) Passwords → bcrypt hash (no more plain-text passwords)
--  2) Nobody can read passwords through the public API key
--  3) Secure login function  pms_login(email, password)
--  4) Speed indexes
--  5) Shared settings (daily target) + realtime live refresh
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;
set search_path = public, extensions;

-- ---------- 1) password hashing ----------
alter table public.app_users add column if not exists password_hash text;
alter table public.app_users alter column password drop not null;

-- hash every existing plain password, then blank the plain column
update public.app_users
   set password_hash = crypt(password, gen_salt('bf'))
 where password is not null and password <> '';
update public.app_users set password = null where password_hash is not null;

-- any future insert/update that sends "password" is hashed automatically
create or replace function public.pms_hash_password()
returns trigger language plpgsql
set search_path = public, extensions
as $$
begin
  if new.password is not null and new.password <> '' then
    new.password_hash := crypt(new.password, gen_salt('bf'));
  end if;
  new.password := null;
  return new;
end $$;

drop trigger if exists trg_pms_hash_password on public.app_users;
create trigger trg_pms_hash_password
  before insert or update on public.app_users
  for each row execute function public.pms_hash_password();

-- ---------- 2) hide password columns from the public (anon) key ----------
revoke select on table public.app_users from anon, authenticated;
grant select (id, name, email, phone, role, allowed_steps, can_edit_entries, active)
  on table public.app_users to anon, authenticated;

-- ---------- 3) secure login ----------
create or replace function public.pms_login(p_email text, p_password text)
returns json
language sql
security definer
set search_path = public, extensions
as $$
  select json_build_object(
           'id', u.id, 'name', u.name, 'email', u.email, 'phone', u.phone,
           'role', u.role, 'allowed_steps', u.allowed_steps,
           'can_edit_entries', u.can_edit_entries, 'active', u.active)
    from public.app_users u
   where lower(u.email) = lower(trim(p_email))
     and u.active = true
     and u.password_hash is not null
     and u.password_hash = crypt(p_password, u.password_hash)
   limit 1;
$$;
revoke all on function public.pms_login(text, text) from public;
grant execute on function public.pms_login(text, text) to anon, authenticated;

-- ---------- 4) speed indexes ----------
create index if not exists idx_batch_steps_batch   on public.batch_steps(batch_id);
create index if not exists idx_step_entries_batch  on public.step_entries(batch_id);
create index if not exists idx_step_entries_time   on public.step_entries(created_at);
create index if not exists idx_sales_batch         on public.sales(batch_id);
create index if not exists idx_sales_entry         on public.sales(step_entry_id);
create index if not exists idx_scrap_batch         on public.scrap_lots(batch_id);
create index if not exists idx_scrap_entry         on public.scrap_lots(step_entry_id);
create index if not exists idx_batches_status      on public.batches(status);

-- ---------- 5) shared settings + realtime ----------
alter table public.company_profile add column if not exists settings jsonb default '{}'::jsonb;

do $$
declare t text;
begin
  foreach t in array array['batches','batch_steps','step_entries','sales','scrap_lots'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when others then null;  -- already added / publication missing
    end;
  end loop;
end $$;

-- ---------- check ----------
-- select id, name, email, (password is null) as plain_removed, (password_hash is not null) as hashed from public.app_users;
