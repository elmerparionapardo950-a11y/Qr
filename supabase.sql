-- Ejecuta TODO este archivo en Supabase → SQL Editor. Se puede ejecutar más de una vez.

-- ───────── Tablas ─────────
create table if not exists turnos (
  id serial primary key,
  nombre text not null,
  hora_inicio time not null,
  hora_fin time not null,
  tolerancia_min int not null default 5
);
insert into turnos (nombre, hora_inicio, hora_fin, tolerancia_min)
select * from (values
  ('Mañana', '07:30'::time, '13:00'::time, 5),
  ('Tarde',  '13:00'::time, '18:30'::time, 5),
  ('Noche',  '18:30'::time, '22:30'::time, 5)
) v(nombre, hora_inicio, hora_fin, tolerancia_min)
where not exists (select 1 from turnos);

create table if not exists profesores (
  id uuid primary key default gen_random_uuid(),
  dni text unique not null,
  nombres text not null,
  apellidos text not null,
  email text,
  telefono text,
  turno_id int references turnos(id),
  qr_token text unique not null default encode(gen_random_bytes(16), 'hex'),
  activo boolean default true,
  created_at timestamptz default now()
);

create table if not exists asistencias (
  id uuid primary key default gen_random_uuid(),
  profesor_id uuid references profesores(id) on delete cascade,
  turno_id int references turnos(id),
  fecha date not null,
  hora_ingreso timestamptz,
  hora_salida timestamptz,
  estado text check (estado in ('puntual','tardanza')),
  minutos_tarde int default 0,
  unique (profesor_id, fecha, turno_id)
);

-- Ya no se usa: el login del admin ahora es Supabase Auth.
drop table if exists admins;

-- ───────── Seguridad (RLS) ─────────
-- Solo usuarios con sesión iniciada (el admin) pueden leer/escribir las tablas.
-- El escáner NO toca las tablas: usa la función registrar_asistencia (abajo).
alter table turnos enable row level security;
alter table profesores enable row level security;
alter table asistencias enable row level security;

drop policy if exists admin_turnos on turnos;
drop policy if exists admin_profesores on profesores;
drop policy if exists admin_asistencias on asistencias;
create policy admin_turnos      on turnos      for all to authenticated using (true) with check (true);
create policy admin_profesores  on profesores  for all to authenticated using (true) with check (true);
create policy admin_asistencias on asistencias for all to authenticated using (true) with check (true);

-- ───────── Función del escáner (hora del servidor, zona Lima) ─────────
create or replace function registrar_asistencia(p_token text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  p profesores%rowtype;
  t turnos%rowtype;
  a asistencias%rowtype;
  ahora timestamptz := now();
  hoy date := (now() at time zone 'America/Lima')::date;
  hora_txt text := to_char(now() at time zone 'America/Lima', 'HH24:MI:SS');
  inicio timestamptz;
  tarde boolean;
  min int;
  nombre text;
begin
  if p_token is null or p_token !~ '^[a-f0-9]{32}$' then
    return json_build_object('ok', false, 'mensaje', 'Código QR no válido.');
  end if;

  select * into p from profesores where qr_token = p_token and activo = true;
  if not found then
    return json_build_object('ok', false, 'mensaje', 'QR no reconocido o profesor inactivo.');
  end if;
  if p.turno_id is null then
    return json_build_object('ok', false, 'mensaje', 'El profesor no tiene turno asignado.');
  end if;

  select * into t from turnos where id = p.turno_id;
  nombre := p.nombres || ' ' || p.apellidos;

  select * into a from asistencias
   where profesor_id = p.id and fecha = hoy and turno_id = t.id;

  -- INGRESO
  if not found then
    inicio := (hoy + t.hora_inicio) at time zone 'America/Lima';
    tarde := ahora > inicio + make_interval(mins => t.tolerancia_min);
    min := case when tarde then floor(extract(epoch from (ahora - inicio)) / 60)::int else 0 end;
    begin
      insert into asistencias (profesor_id, turno_id, fecha, hora_ingreso, estado, minutos_tarde)
      values (p.id, t.id, hoy, ahora, case when tarde then 'tardanza' else 'puntual' end, min);
    exception when unique_violation then
      return json_build_object('ok', true, 'mensaje', 'Ya registraste tu ingreso hace un momento.',
        'tipo', 'duplicado', 'estado', 'aviso', 'profesor', nombre, 'turno', t.nombre, 'hora', hora_txt);
    end;
    return json_build_object('ok', true,
      'mensaje', case when tarde then 'Ingreso con tardanza (' || min || ' min)' else 'Ingreso registrado' end,
      'tipo', 'ingreso', 'estado', case when tarde then 'tardanza' else 'puntual' end,
      'profesor', nombre, 'turno', t.nombre, 'hora', hora_txt);
  end if;

  -- SALIDA
  if a.hora_salida is null then
    if ahora - a.hora_ingreso < interval '2 minutes' then
      return json_build_object('ok', true, 'mensaje', 'Ya registraste tu ingreso hace un momento.',
        'tipo', 'duplicado', 'estado', 'aviso', 'profesor', nombre, 'turno', t.nombre, 'hora', hora_txt);
    end if;
    update asistencias set hora_salida = ahora where id = a.id;
    return json_build_object('ok', true, 'mensaje', 'Salida registrada',
      'tipo', 'salida', 'estado', 'puntual', 'profesor', nombre, 'turno', t.nombre, 'hora', hora_txt);
  end if;

  return json_build_object('ok', true, 'mensaje', 'Tu asistencia de hoy ya está completa.',
    'tipo', 'completo', 'estado', 'aviso', 'profesor', nombre, 'turno', t.nombre, 'hora', hora_txt);
end;
$$;

revoke all on function registrar_asistencia(text) from public;
grant execute on function registrar_asistencia(text) to anon, authenticated;
