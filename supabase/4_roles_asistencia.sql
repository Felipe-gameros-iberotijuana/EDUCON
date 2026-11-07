-- EduCon IBERO Tijuana · roles por sección y asistencia por QR
-- Roles: admin (todo + equipo), coordinacion (todo), cobranza (alumnos, cobranza, pendientes),
--        asistencia (alumnos en lectura, asistencia, pendientes), lectura (ve todo, no edita).

-- 1) Rol de cada persona
alter table public.perfiles add column if not exists rol text not null default 'coordinacion';
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check check (rol in ('admin','coordinacion','cobranza','asistencia','lectura'));

-- Nadie puede cambiarse su propio rol: solo nombre y foto
revoke update on public.perfiles from authenticated;
grant update (nombre, avatar_url) on public.perfiles to authenticated;

create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select rol from public.perfiles where id = auth.uid()), 'ninguno');
$$;

-- ¿Puede el usuario actual leer / escribir esta colección?
create or replace function public.puede(p_col text, p_escribir boolean) returns boolean
language sql stable security definer set search_path = public as $$
  select case public.mi_rol()
    when 'admin'        then true
    when 'coordinacion' then true
    when 'lectura'      then not p_escribir
    when 'cobranza'     then case when p_escribir
                               then p_col in ('alumnos','tareas')
                               else p_col in ('alumnos','tareas','generaciones','programas','config','preguntas') end
    when 'asistencia'   then case when p_escribir
                               then p_col in ('asistencias','qr','tareas')
                               else p_col in ('alumnos','asistencias','qr','tareas','generaciones','programas','config','profesores') end
    else false end;
$$;

drop policy if exists "equipo lee docs"   on public.docs;
drop policy if exists "equipo crea docs"  on public.docs;
drop policy if exists "equipo edita docs" on public.docs;
drop policy if exists "equipo borra docs" on public.docs;
create policy "lee segun rol"    on public.docs for select to authenticated using (public.puede(col, false));
create policy "crea segun rol"   on public.docs for insert to authenticated with check (public.puede(col, true));
create policy "edita segun rol"  on public.docs for update to authenticated using (public.puede(col, true)) with check (public.puede(col, true));
create policy "borra segun rol"  on public.docs for delete to authenticated using (public.puede(col, true));

-- Solo admin asigna roles
create or replace function public.asignar_rol(p_usuario uuid, p_rol text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.mi_rol() <> 'admin' then raise exception 'Solo un administrador puede cambiar roles'; end if;
  if p_usuario = auth.uid() and p_rol <> 'admin' then raise exception 'No puedes quitarte el rol de administrador a ti mismo'; end if;
  update public.perfiles set rol = p_rol where id = p_usuario;
end $$;

-- 2) Asistencia por QR (la usan alumnos sin cuenta, solo con un código vigente)
create or replace function public.registrar_asistencia_qr(p_token text, p_dato text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  q jsonb; a record; dig text; correo text; aid text;
begin
  select data into q from public.docs where col = 'qr' and id = p_token;
  if q is null or (q->>'expira')::timestamptz < now() then
    return jsonb_build_object('ok', false, 'error', 'Este código ya no es válido. Pide a la encargada que muestre el QR de hoy.');
  end if;
  correo := lower(trim(coalesce(p_dato, '')));
  dig := right(regexp_replace(coalesce(p_dato, ''), '\D', '', 'g'), 10);
  if length(correo) < 5 then
    return jsonb_build_object('ok', false, 'error', 'Escribe tu matrícula, correo o teléfono.');
  end if;
  select d.id, d.data into a from public.docs d
   where d.col = 'alumnos' and d.data->>'generacionId' = q->>'genId'
     and coalesce(d.data->>'estatus', 'Activo') <> 'Baja'
     and (lower(trim(coalesce(d.data->>'correo', ''))) = correo
          or lower(trim(coalesce(d.data->>'matricula', ''))) = correo
          or (length(dig) = 10 and right(regexp_replace(coalesce(d.data->>'telefono', ''), '\D', '', 'g'), 10) = dig))
   limit 1;
  if a.id is null then
    return jsonb_build_object('ok', false, 'error', 'No te encontramos en este grupo. Revisa tu matrícula, correo o teléfono, o avisa a la encargada.');
  end if;
  aid := (q->>'genId') || '__' || (q->>'fecha') || '__' || a.id;
  insert into public.docs (col, id, data, updated_by)
  values ('asistencias', aid,
          jsonb_build_object('genId', q->>'genId', 'fecha', q->>'fecha', 'alumnoId', a.id, 'estado', 'P', 'via', 'QR', 'hora', to_char(now() at time zone 'America/Tijuana', 'HH24:MI')),
          null)
  on conflict (col, id) do update
    set data = public.docs.data || jsonb_build_object('estado', 'P', 'via', 'QR', 'hora', to_char(now() at time zone 'America/Tijuana', 'HH24:MI')),
        updated_at = now();
  return jsonb_build_object('ok', true, 'nombre', trim(coalesce(a.data->>'nombre', '') || ' ' || coalesce(a.data->>'apellidos', '')));
end $$;

revoke execute on function public.mi_rol() from public, anon;
revoke execute on function public.puede(text, boolean) from public, anon;
revoke execute on function public.asignar_rol(uuid, text) from public, anon;
grant execute on function public.mi_rol() to authenticated;
grant execute on function public.puede(text, boolean) to authenticated;
grant execute on function public.asignar_rol(uuid, text) to authenticated;
revoke execute on function public.registrar_asistencia_qr(text, text) from public;
grant execute on function public.registrar_asistencia_qr(text, text) to anon, authenticated;
