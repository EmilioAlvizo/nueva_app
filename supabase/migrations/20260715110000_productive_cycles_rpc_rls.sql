-- Productive-cycle authorization and versioned mutation API.
-- Roll back policy behavior by dropping ciclos_lectura_miembro and
-- miembros_actualizacion_owner, recreating every ciclos_productivos policy
-- removed below and the former miembros_granja UPDATE policy (for example,
-- actualizar rol) from the pre-migration schema, then restoring prior grants.
begin;

set local lock_timeout = '5s';

create or replace function public.puede_leer_granja(p_granja_id uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.granjas granja
    where granja.id = p_granja_id and (
      granja.owner_id = auth.uid() or exists (
        select 1 from public.miembros_granja miembro
        where miembro.granja_id = granja.id and miembro.user_id = auth.uid()
      )
    )
  );
$$;

create or replace function public.puede_editar_granja(p_granja_id uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.granjas granja
    where granja.id = p_granja_id and (
      granja.owner_id = auth.uid() or exists (
        select 1 from public.miembros_granja miembro
        where miembro.granja_id = granja.id and miembro.user_id = auth.uid()
          and miembro.rol in ('owner', 'editor')
      )
    )
  );
$$;

create or replace function public.agregar_miembro_ciclo(p_ciclo_id uuid, p_animal_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  v_ciclo public.ciclos_productivos;
  v_animal public.animales;
  v_costo numeric;
  v_fuente text;
  v_costo_previo public.ciclo_costos_adquisicion;
begin
  select * into v_ciclo from public.ciclos_productivos where id = p_ciclo_id for update;
  select * into v_animal from public.animales where id = p_animal_id for update;
  if v_ciclo.id is null or v_animal.id is null or v_animal.granja_id <> v_ciclo.granja_id or v_animal.tipo_animal_id <> v_ciclo.tipo_animal_id then
    raise exception 'Cycle members must belong to the cycle farm and animal type';
  end if;
  if not v_animal.activo then raise exception 'Inactive animals cannot join a cycle'; end if;
  if exists (select 1 from public.ciclo_miembros where animal_id = p_animal_id and left_at is null) then
    raise exception 'Animal already belongs to an active cycle';
  end if;

  insert into public.ciclo_miembros (ciclo_id, animal_id, created_by)
  values (p_ciclo_id, p_animal_id, auth.uid());

  if exists (select 1 from public.cat_productos where id = v_ciclo.producto_id and codigo = 'carne') then
    select * into v_costo_previo from public.ciclo_costos_adquisicion where animal_id = p_animal_id;
    if found and v_costo_previo.ciclo_id <> p_ciclo_id then
      raise exception 'Meat acquisition cost is already claimed by another lifetime cycle';
    end if;
    if not found then
      v_costo := v_animal.costo_adquisicion;
      v_fuente := 'animal';
      if v_costo is null then
        select alta.costo_total / nullif(alta.cantidad_animales, 0) into v_costo
        from public.altas_animales alta
        where alta.id = v_animal.alta_id
          and alta.granja_id = v_ciclo.granja_id
          and alta.tipo_animal_id = v_ciclo.tipo_animal_id;
        v_fuente := 'alta_prorrateada';
      end if;
      if v_costo is null then raise exception 'Meat membership requires a resolvable acquisition cost'; end if;
      insert into public.ciclo_costos_adquisicion (ciclo_id, animal_id, costo_snapshot, fuente)
      values (p_ciclo_id, p_animal_id, v_costo, v_fuente);
    end if;
  end if;
end;
$$;

create or replace function public.crear_ciclo_productivo(
  p_granja_id uuid, p_producto_codigo text, p_tipo_animal_id uuid, p_animal_ids uuid[],
  p_fecha_inicio date default current_date, p_nombre text default null, p_notas text default null
) returns public.ciclos_productivos language plpgsql security definer set search_path = public, auth as $$
declare v_producto_id uuid; v_ciclo public.ciclos_productivos; v_animal_id uuid;
begin
  if auth.uid() is null or not public.puede_editar_granja(p_granja_id) then raise exception 'Farm editor access required'; end if;
  if coalesce(cardinality(p_animal_ids), 0) = 0 or array_position(p_animal_ids, null) is not null then raise exception 'At least one explicit member is required'; end if;
  if cardinality(p_animal_ids) <> (select count(distinct id) from unnest(p_animal_ids) id) then raise exception 'Cycle members must be unique'; end if;
  select id into v_producto_id from public.cat_productos where codigo = p_producto_codigo and activo;
  if not found then raise exception 'Active product not found'; end if;
  if not exists (select 1 from public.tipo_animal where id = p_tipo_animal_id and granja_id = p_granja_id) then raise exception 'Animal type does not belong to farm'; end if;

  insert into public.ciclos_productivos (granja_id, tipo_animal_id, producto_id, tipo_produccion, unidad_produccion, nombre, fecha_inicio, notas, created_by)
  select p_granja_id, p_tipo_animal_id, producto.id, producto.codigo, unidad.codigo, nullif(trim(p_nombre), ''), coalesce(p_fecha_inicio, current_date), nullif(trim(p_notas), ''), auth.uid()
  from public.cat_productos producto join public.cat_unidades unidad on unidad.id = producto.unidad_predeterminada_id
  where producto.id = v_producto_id returning * into v_ciclo;
  foreach v_animal_id in array p_animal_ids loop perform public.agregar_miembro_ciclo(v_ciclo.id, v_animal_id); end loop;
  return v_ciclo;
end;
$$;

create or replace function public.editar_miembros_ciclo(
  p_ciclo_id uuid, p_version integer, p_agregar uuid[] default '{}', p_retirar uuid[] default '{}'
) returns public.ciclos_productivos language plpgsql security definer set search_path = public, auth as $$
declare v_ciclo public.ciclos_productivos; v_animal_id uuid;
begin
  select * into v_ciclo from public.ciclos_productivos where id = p_ciclo_id for update;
  if not found or not public.puede_editar_granja(v_ciclo.granja_id) then raise exception 'Farm editor access required'; end if;
  if not v_ciclo.activo then raise exception 'Closed cycles are immutable'; end if;
  if p_version is null then raise exception 'Cycle version is required'; end if;
  if v_ciclo.version <> p_version then raise exception 'Cycle has changed; refresh before editing'; end if;
  foreach v_animal_id in array coalesce(p_retirar, '{}'::uuid[]) loop
    update public.ciclo_miembros set left_at = now() where ciclo_id = v_ciclo.id and animal_id = v_animal_id and left_at is null;
  end loop;
  foreach v_animal_id in array coalesce(p_agregar, '{}'::uuid[]) loop perform public.agregar_miembro_ciclo(v_ciclo.id, v_animal_id); end loop;
  update public.ciclos_productivos set version = version + 1 where id = v_ciclo.id returning * into v_ciclo;
  return v_ciclo;
end;
$$;

create or replace function public.registrar_evento_ciclo(
  p_ciclo_id uuid, p_version integer, p_fecha date, p_metricas text[], p_valores numeric[], p_notas text default null
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare v_ciclo public.ciclos_productivos; v_evento_id uuid;
begin
  select * into v_ciclo from public.ciclos_productivos where id = p_ciclo_id for update;
  if not found or not public.puede_editar_granja(v_ciclo.granja_id) then raise exception 'Farm editor access required'; end if;
  if p_version is null then raise exception 'Cycle version is required'; end if;
  if not v_ciclo.activo or v_ciclo.version <> p_version then raise exception 'Cycle is closed or stale'; end if;
  if coalesce(cardinality(p_metricas), 0) = 0 or cardinality(p_metricas) <> cardinality(p_valores) or array_position(p_valores, null) is not null then raise exception 'Metric names and values must match'; end if;
  if cardinality(p_metricas) <> (select count(distinct codigo) from unnest(p_metricas) codigo) then raise exception 'Metric codes must be unique'; end if;
  if (select count(*) from public.cat_metricas_producto where producto_id = v_ciclo.producto_id and codigo = any(p_metricas) and activo) <> cardinality(p_metricas) then raise exception 'Metric does not belong to cycle product'; end if;
  insert into public.eventos_produccion (ciclo_id, producto_id, fecha, notas, created_by) values (v_ciclo.id, v_ciclo.producto_id, coalesce(p_fecha, current_date), nullif(trim(p_notas), ''), auth.uid()) returning id into v_evento_id;
  insert into public.evento_mediciones (evento_id, metrica_id, valor)
  select v_evento_id, metrica.id, valores.valor
  from unnest(p_metricas, p_valores) valores(codigo, valor)
  join public.cat_metricas_producto metrica on metrica.producto_id = v_ciclo.producto_id and metrica.codigo = valores.codigo;
  update public.ciclos_productivos set version = version + 1 where id = v_ciclo.id;
  return v_evento_id;
end;
$$;

create or replace function public.registrar_compra_alimento(p_lote_id uuid, p_ciclo_id uuid, p_version integer)
returns public.lotes_alimento language plpgsql security definer set search_path = public, auth as $$
declare v_ciclo public.ciclos_productivos; v_lote public.lotes_alimento;
begin
  select * into v_ciclo from public.ciclos_productivos where id = p_ciclo_id for update;
  select * into v_lote from public.lotes_alimento where id = p_lote_id for update;
  if v_ciclo.id is null or v_lote.id is null or not public.puede_editar_granja(v_ciclo.granja_id) or v_lote.granja_id <> v_ciclo.granja_id then raise exception 'Farm editor access required'; end if;
  if p_version is null then raise exception 'Cycle version is required'; end if;
  if not v_ciclo.activo or v_ciclo.version <> p_version then raise exception 'Cycle is closed or stale'; end if;
  if v_lote.ciclo_id is not null and v_lote.ciclo_id <> v_ciclo.id then raise exception 'Feed purchase is already assigned to another cycle'; end if;
  update public.lotes_alimento set ciclo_id = v_ciclo.id where id = v_lote.id returning * into v_lote;
  return v_lote;
end;
$$;

create or replace function public.registrar_ajuste_ciclo(
  p_ciclo_id uuid, p_version integer, p_tipo public.tipo_movimiento, p_concepto text, p_importe numeric, p_fecha date default current_date, p_notas text default null
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare v_ciclo public.ciclos_productivos; v_id uuid;
begin
  select * into v_ciclo from public.ciclos_productivos where id = p_ciclo_id for update;
  if not found or not public.puede_editar_granja(v_ciclo.granja_id) then raise exception 'Farm editor access required'; end if;
  if p_version is null then raise exception 'Cycle version is required'; end if;
  if not v_ciclo.activo or v_ciclo.version <> p_version or p_importe <= 0 or nullif(trim(p_concepto), '') is null then raise exception 'Cycle is closed, stale, or adjustment is invalid'; end if;
  insert into public.gastos_ingresos_extra (granja_id, ciclo_id, tipo, concepto, importe, fecha, notas, created_by)
  values (v_ciclo.granja_id, v_ciclo.id, p_tipo, trim(p_concepto), p_importe, coalesce(p_fecha, current_date), nullif(trim(p_notas), ''), auth.uid()) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.cerrar_ciclo(p_ciclo_id uuid, p_version integer, p_fecha_fin date default current_date)
returns public.ciclos_productivos language plpgsql security definer set search_path = public, auth as $$
declare v_ciclo public.ciclos_productivos;
begin
  select * into v_ciclo from public.ciclos_productivos where id = p_ciclo_id for update;
  if not found or not public.puede_editar_granja(v_ciclo.granja_id) then raise exception 'Farm editor access required'; end if;
  if p_version is null then raise exception 'Cycle version is required'; end if;
  if not v_ciclo.activo or v_ciclo.version <> p_version or coalesce(p_fecha_fin, current_date) < v_ciclo.fecha_inicio then raise exception 'Cycle is already closed, stale, or has an invalid closure date'; end if;
  update public.ciclo_miembros set left_at = now() where ciclo_id = v_ciclo.id and left_at is null;
  update public.ciclos_productivos set activo = false, fecha_fin = coalesce(p_fecha_fin, current_date), version = version + 1 where id = v_ciclo.id returning * into v_ciclo;
  return v_ciclo;
end;
$$;

do $$
declare policy_name text;
begin
  for policy_name in select policyname from pg_policies where schemaname = 'public' and tablename = 'ciclos_productivos' loop
    execute format('drop policy %I on public.ciclos_productivos', policy_name);
  end loop;
  for policy_name in select policyname from pg_policies where schemaname = 'public' and tablename = 'miembros_granja' and cmd = 'UPDATE' loop
    execute format('drop policy %I on public.miembros_granja', policy_name);
  end loop;
end;
$$;

create policy ciclos_lectura_miembro on public.ciclos_productivos for select using (public.puede_leer_granja(granja_id));
create policy miembros_actualizacion_owner on public.miembros_granja for update using (
  exists (select 1 from public.granjas where id = miembros_granja.granja_id and owner_id = auth.uid())
) with check (exists (select 1 from public.granjas where id = miembros_granja.granja_id and owner_id = auth.uid()));

alter table public.ciclo_miembros enable row level security;
alter table public.ciclo_costos_adquisicion enable row level security;
alter table public.eventos_produccion enable row level security;
alter table public.evento_mediciones enable row level security;
alter table public.cat_unidades enable row level security;
alter table public.cat_productos enable row level security;
alter table public.cat_metricas_producto enable row level security;

create policy catalogos_lectura on public.cat_unidades for select using (auth.uid() is not null);
create policy productos_lectura on public.cat_productos for select using (auth.uid() is not null);
create policy metricas_lectura on public.cat_metricas_producto for select using (auth.uid() is not null);
create policy miembros_ciclo_lectura on public.ciclo_miembros for select using (exists (select 1 from public.ciclos_productivos ciclo where ciclo.id = ciclo_id and public.puede_leer_granja(ciclo.granja_id)));
create policy costos_ciclo_lectura on public.ciclo_costos_adquisicion for select using (exists (select 1 from public.ciclos_productivos ciclo where ciclo.id = ciclo_id and public.puede_leer_granja(ciclo.granja_id)));
create policy eventos_ciclo_lectura on public.eventos_produccion for select using (exists (select 1 from public.ciclos_productivos ciclo where ciclo.id = ciclo_id and public.puede_leer_granja(ciclo.granja_id)));
create policy mediciones_ciclo_lectura on public.evento_mediciones for select using (exists (select 1 from public.eventos_produccion evento join public.ciclos_productivos ciclo on ciclo.id = evento.ciclo_id where evento.id = evento_id and public.puede_leer_granja(ciclo.granja_id)));

revoke all on public.ciclos_productivos, public.ciclo_miembros, public.ciclo_costos_adquisicion, public.eventos_produccion, public.evento_mediciones, public.cat_unidades, public.cat_productos, public.cat_metricas_producto from anon, authenticated;
revoke all on public.miembros_granja, public.lotes_alimento, public.registros_produccion, public.salidas_produccion, public.gastos_ingresos_extra from anon;
grant select on public.ciclos_productivos, public.ciclo_miembros, public.ciclo_costos_adquisicion, public.eventos_produccion, public.evento_mediciones, public.cat_unidades, public.cat_productos, public.cat_metricas_producto to authenticated;
revoke all on function public.agregar_miembro_ciclo(uuid, uuid) from public, anon, authenticated;
revoke all on function public.puede_leer_granja(uuid), public.puede_editar_granja(uuid) from public, anon;
grant execute on function public.puede_leer_granja(uuid), public.puede_editar_granja(uuid) to authenticated;
revoke all on function public.crear_ciclo_productivo(uuid, text, uuid, uuid[], date, text, text), public.editar_miembros_ciclo(uuid, integer, uuid[], uuid[]), public.registrar_evento_ciclo(uuid, integer, date, text[], numeric[], text), public.registrar_compra_alimento(uuid, uuid, integer), public.registrar_ajuste_ciclo(uuid, integer, public.tipo_movimiento, text, numeric, date, text), public.cerrar_ciclo(uuid, integer, date) from public, anon;
grant execute on function public.crear_ciclo_productivo(uuid, text, uuid, uuid[], date, text, text), public.editar_miembros_ciclo(uuid, integer, uuid[], uuid[]), public.registrar_evento_ciclo(uuid, integer, date, text[], numeric[], text), public.registrar_compra_alimento(uuid, uuid, integer), public.registrar_ajuste_ciclo(uuid, integer, public.tipo_movimiento, text, numeric, date, text), public.cerrar_ciclo(uuid, integer, date) to authenticated;

commit;
