-- EduCon IBERO Tijuana · estructura de la base de datos
-- Pégalo completo en Supabase → SQL Editor → New query → Run. Solo se corre una vez.

-- 1) Documentos de la app (diplomados, profesores, vinculación, pendientes, etc.)
create table if not exists public.docs (
  col         text        not null,
  id          text        not null,
  data        jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  updated_by  uuid        references auth.users(id) on delete set null default auth.uid(),
  primary key (col, id)
);

-- 2) Perfiles del equipo (nombre que se ve en la app)
create table if not exists public.perfiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nombre     text,
  email      text,
  avatar_url text
);

-- 3) Seguridad: solo usuarios con sesión (invitados por ti) pueden ver y editar
alter table public.docs     enable row level security;
alter table public.perfiles enable row level security;

drop policy if exists "equipo lee docs"      on public.docs;
drop policy if exists "equipo crea docs"     on public.docs;
drop policy if exists "equipo edita docs"    on public.docs;
drop policy if exists "equipo borra docs"    on public.docs;
create policy "equipo lee docs"   on public.docs for select to authenticated using (true);
create policy "equipo crea docs"  on public.docs for insert to authenticated with check (true);
create policy "equipo edita docs" on public.docs for update to authenticated using (true) with check (true);
create policy "equipo borra docs" on public.docs for delete to authenticated using (true);

drop policy if exists "equipo ve perfiles"        on public.perfiles;
drop policy if exists "cada quien edita su perfil" on public.perfiles;
drop policy if exists "cada quien crea su perfil"  on public.perfiles;
create policy "equipo ve perfiles"         on public.perfiles for select to authenticated using (true);
create policy "cada quien crea su perfil"  on public.perfiles for insert to authenticated with check (id = auth.uid());
create policy "cada quien edita su perfil" on public.perfiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- 4) Al invitar a alguien se le crea su perfil automáticamente
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, email, nombre)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.crear_perfil();
revoke execute on function public.crear_perfil() from public, anon, authenticated;

-- 5) Cambios en vivo (que todo se mueva solo para todos)
alter table public.docs replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;
