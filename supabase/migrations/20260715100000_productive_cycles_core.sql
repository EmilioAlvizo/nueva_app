-- Additive productive-cycle foundation. Roll back by dropping only the objects
-- introduced here after dependent migrations are reverted; legacy rows remain.
begin;

set local lock_timeout = '5s';

create table if not exists public.cat_unidades (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  nombre text not null,
  activo boolean not null default true
);

create table if not exists public.cat_productos (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  nombre text not null,
  unidad_predeterminada_id uuid not null references public.cat_unidades(id),
  activo boolean not null default true
);

create table if not exists public.cat_metricas_producto (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references public.cat_productos(id) on delete cascade,
  codigo text not null,
  nombre text not null,
  unidad_id uuid not null references public.cat_unidades(id),
  rol text not null check (rol in ('produccion', 'merma', 'peso', 'ingreso', 'precio_venta')),
  activo boolean not null default true,
  unique (producto_id, codigo)
);

insert into public.cat_unidades (codigo, nombre) values
  ('pieza', 'Piece'), ('kilogramo', 'Kilogram'), ('moneda', 'Currency')
on conflict (codigo) do update set nombre = excluded.nombre;

insert into public.cat_productos (codigo, nombre, unidad_predeterminada_id)
select value.codigo, value.nombre, unidad.id
from (values ('huevo', 'Egg', 'pieza'), ('carne', 'Meat', 'kilogramo')) as value(codigo, nombre, unidad_codigo)
join public.cat_unidades unidad on unidad.codigo = value.unidad_codigo
on conflict (codigo) do update
set nombre = excluded.nombre, unidad_predeterminada_id = excluded.unidad_predeterminada_id;

insert into public.cat_metricas_producto (producto_id, codigo, nombre, unidad_id, rol)
select producto.id, value.codigo, value.nombre, unidad.id, value.rol
from (values
  ('huevo', 'huevos_buenos', 'Good eggs', 'pieza', 'produccion'),
  ('huevo', 'huevos_rotos', 'Broken eggs', 'pieza', 'merma'),
  ('huevo', 'venta_huevos', 'Egg sale revenue', 'moneda', 'ingreso'),
  ('carne', 'peso', 'Weight', 'kilogramo', 'peso'),
  ('carne', 'produccion_carne', 'Meat output', 'kilogramo', 'produccion'),
  ('carne', 'venta_carne', 'Meat sale revenue', 'moneda', 'ingreso'),
  ('carne', 'precio_venta', 'Selling price', 'moneda', 'precio_venta')
) as value(producto_codigo, codigo, nombre, unidad_codigo, rol)
join public.cat_productos producto on producto.codigo = value.producto_codigo
join public.cat_unidades unidad on unidad.codigo = value.unidad_codigo
on conflict (producto_id, codigo) do update
set nombre = excluded.nombre, unidad_id = excluded.unidad_id, rol = excluded.rol;

alter table public.ciclos_productivos
  add column if not exists producto_id uuid references public.cat_productos(id),
  add column if not exists version integer not null default 1,
  add constraint ciclos_productivos_version_positiva check (version > 0);

create table if not exists public.ciclo_miembros (
  id uuid primary key default gen_random_uuid(),
  ciclo_id uuid not null references public.ciclos_productivos(id),
  animal_id uuid not null references public.animales(id),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  created_by uuid not null references public.perfiles(id),
  check (left_at is null or left_at >= joined_at)
);

create unique index if not exists ciclo_miembros_animal_activo_unico
  on public.ciclo_miembros (animal_id) where left_at is null;
create index if not exists ciclo_miembros_ciclo_abierto_idx
  on public.ciclo_miembros (ciclo_id) where left_at is null;

create table if not exists public.ciclo_costos_adquisicion (
  id uuid primary key default gen_random_uuid(),
  ciclo_id uuid not null references public.ciclos_productivos(id),
  animal_id uuid not null references public.animales(id),
  costo_snapshot numeric not null check (costo_snapshot >= 0),
  fuente text not null check (fuente in ('animal', 'alta_prorrateada')),
  captured_at timestamptz not null default now(),
  unique (animal_id)
);

create table if not exists public.eventos_produccion (
  id uuid primary key default gen_random_uuid(),
  ciclo_id uuid not null references public.ciclos_productivos(id),
  producto_id uuid not null references public.cat_productos(id),
  fecha date not null default current_date,
  notas text,
  created_by uuid not null references public.perfiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.evento_mediciones (
  evento_id uuid not null references public.eventos_produccion(id) on delete cascade,
  metrica_id uuid not null references public.cat_metricas_producto(id),
  valor numeric not null check (valor >= 0),
  primary key (evento_id, metrica_id)
);

create index if not exists eventos_produccion_ciclo_fecha_idx
  on public.eventos_produccion (ciclo_id, fecha, created_at);

create or replace function public.rechazar_mutacion_ciclo_cerrado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_anterior_ciclo_id uuid;
  v_ciclo_id uuid;
begin
  if tg_op <> 'INSERT' and tg_table_name = 'evento_mediciones' then
    select evento.ciclo_id into v_anterior_ciclo_id
    from public.eventos_produccion evento where evento.id = old.evento_id;
  elsif tg_op <> 'INSERT' then
    v_anterior_ciclo_id := old.ciclo_id;
  end if;
  if tg_op <> 'DELETE' and tg_table_name = 'evento_mediciones' then
    select evento.ciclo_id into v_ciclo_id
    from public.eventos_produccion evento
    where evento.id = new.evento_id;
  elsif tg_op <> 'DELETE' then
    v_ciclo_id := new.ciclo_id;
  end if;

  if exists (
    select 1 from public.ciclos_productivos ciclo
    where ciclo.id in (v_anterior_ciclo_id, v_ciclo_id) and not ciclo.activo
  ) then
    raise exception 'Closed cycles are immutable';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function public.proteger_cierre_ciclo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not old.activo and new is distinct from old
    and current_setting('app.legacy_cycle_backfill', true) is distinct from 'on' then
    raise exception 'Closed cycles cannot be changed or reopened';
  end if;
  return new;
end;
$$;

create or replace function public.actualizar_version_ciclo_asignado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ciclo_anterior uuid;
  v_ciclo_nuevo uuid;
begin
  if tg_op <> 'INSERT' then v_ciclo_anterior := old.ciclo_id; end if;
  if tg_op <> 'DELETE' then v_ciclo_nuevo := new.ciclo_id; end if;

  if v_ciclo_anterior is not null then
    update public.ciclos_productivos set version = version + 1
    where id = v_ciclo_anterior and activo;
  end if;
  if v_ciclo_nuevo is not null and v_ciclo_nuevo is distinct from v_ciclo_anterior then
    update public.ciclos_productivos set version = version + 1
    where id = v_ciclo_nuevo and activo;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists ciclo_proteger_cierre on public.ciclos_productivos;
create trigger ciclo_proteger_cierre before update on public.ciclos_productivos
for each row execute function public.proteger_cierre_ciclo();

do $$
declare table_name text;
begin
  foreach table_name in array array['ciclo_miembros', 'eventos_produccion', 'evento_mediciones', 'lotes_alimento', 'gastos_ingresos_extra', 'registros_produccion', 'salidas_produccion'] loop
    execute format('drop trigger if exists ciclo_rechazar_cerrado on public.%I', table_name);
    execute format('create trigger ciclo_rechazar_cerrado before insert or update or delete on public.%I for each row execute function public.rechazar_mutacion_ciclo_cerrado()', table_name);
  end loop;
end;
$$;

drop trigger if exists ciclo_actualizar_version_asignado on public.lotes_alimento;
create trigger ciclo_actualizar_version_asignado
after insert or update or delete on public.lotes_alimento
for each row execute function public.actualizar_version_ciclo_asignado();

drop trigger if exists ciclo_actualizar_version_asignado on public.gastos_ingresos_extra;
create trigger ciclo_actualizar_version_asignado
after insert or update or delete on public.gastos_ingresos_extra
for each row execute function public.actualizar_version_ciclo_asignado();

commit;
