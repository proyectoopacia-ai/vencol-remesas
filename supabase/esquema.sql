-- VENCOL REMESAS: registro privado de envíos.
-- Ejecutar una sola vez en Supabase > SQL Editor. Este archivo no contiene datos ni claves.

-- Administradores autorizados, por correo
create table public.administradores (
  email text primary key,
  creado_en timestamptz not null default now()
);

create function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.administradores
    where lower(email) = lower(auth.jwt() ->> 'email')
  );
$$;

-- Envíos
create sequence public.envios_numero;

create table public.envios (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique default 'VR-' || lpad(nextval('public.envios_numero')::text, 6, '0'),
  creado_en timestamptz not null default now(),
  estado text not null default 'pendiente' check (estado in ('pendiente', 'pagado', 'cancelado')),
  pagado_en timestamptz,

  remitente_nombre text not null,
  remitente_documento text not null,
  remitente_telefono text not null,
  metodo_cobro text not null,

  beneficiario_nombre text not null,
  beneficiario_cedula text not null,
  beneficiario_banco text not null,
  beneficiario_cuenta text not null,
  beneficiario_telefono text,

  monto_cop numeric(14, 2) not null check (monto_cop > 0),
  tasa numeric(10, 4) not null check (tasa > 0),
  monto_bs numeric(16, 2) not null check (monto_bs > 0),
  bcv numeric(12, 4) not null check (bcv > 0),
  usdt_compra numeric(12, 4) not null check (usdt_compra > 0),
  usdt_venta numeric(12, 4) not null check (usdt_venta > 0),
  costos_pct numeric(6, 3) not null default 0 check (costos_pct >= 0),
  ganancia_cop numeric(14, 2) generated always as (
    monto_cop - monto_bs * usdt_compra / usdt_venta - monto_cop * costos_pct / 100
  ) stored,

  notas text,
  comprobante_cliente text,
  comprobante_pago text,
  creado_por text not null default (auth.jwt() ->> 'email')
);

create index envios_creado_en on public.envios (creado_en desc);
create index envios_estado on public.envios (estado);

-- Historial de cambios, escrito solo por la base de datos
create table public.envios_historial (
  id bigint generated always as identity primary key,
  envio_id uuid not null,
  codigo text not null,
  accion text not null,
  cambios jsonb not null,
  actor text,
  fecha timestamptz not null default now()
);

create index envios_historial_envio on public.envios_historial (envio_id, fecha desc);

create function public.registrar_cambio() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  diferencias jsonb;
begin
  if tg_op = 'INSERT' then
    diferencias := to_jsonb(new);
  else
    select coalesce(jsonb_object_agg(n.key, jsonb_build_object('antes', o.value, 'despues', n.value)), '{}')
      into diferencias
      from jsonb_each(to_jsonb(new)) n
      join jsonb_each(to_jsonb(old)) o using (key)
     where n.value is distinct from o.value;
  end if;
  insert into public.envios_historial (envio_id, codigo, accion, cambios, actor)
  values (new.id, new.codigo, lower(tg_op), diferencias, auth.jwt() ->> 'email');
  return new;
end;
$$;

create trigger envios_auditoria
  after insert or update on public.envios
  for each row execute function public.registrar_cambio();

-- Seguridad: solo administradores, sin borrar y sin cambiar montos ya registrados
alter table public.administradores enable row level security;
alter table public.envios enable row level security;
alter table public.envios_historial enable row level security;

revoke all on public.administradores, public.envios, public.envios_historial from anon, authenticated;
revoke all on function public.es_admin() from anon;
grant usage on sequence public.envios_numero to authenticated;
grant select on public.administradores, public.envios, public.envios_historial to authenticated;
grant insert (
  remitente_nombre, remitente_documento, remitente_telefono, metodo_cobro,
  beneficiario_nombre, beneficiario_cedula, beneficiario_banco, beneficiario_cuenta, beneficiario_telefono,
  monto_cop, tasa, monto_bs, bcv, usdt_compra, usdt_venta, costos_pct, notas, comprobante_cliente
) on public.envios to authenticated;
grant update (estado, pagado_en, notas, comprobante_cliente, comprobante_pago) on public.envios to authenticated;

create policy "admin ve su acceso" on public.administradores
  for select to authenticated using (public.es_admin());
create policy "admin lee envios" on public.envios
  for select to authenticated using (public.es_admin());
create policy "admin crea envios" on public.envios
  for insert to authenticated with check (public.es_admin());
create policy "admin actualiza envios" on public.envios
  for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy "admin lee historial" on public.envios_historial
  for select to authenticated using (public.es_admin());

-- Comprobantes en almacenamiento privado, sin borrar
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('comprobantes', 'comprobantes', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);

create policy "admin lee comprobantes" on storage.objects
  for select to authenticated using (bucket_id = 'comprobantes' and public.es_admin());
create policy "admin sube comprobantes" on storage.objects
  for insert to authenticated with check (bucket_id = 'comprobantes' and public.es_admin());
