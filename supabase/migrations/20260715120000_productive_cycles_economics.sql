-- Canonical, security-invoker cycle economics. Undefined divisors stay null.
begin;

create or replace view public.v_ciclo_economia
with (security_invoker = true) as
select
  ciclo.id as ciclo_id,
  coalesce(alimento.total, 0) as costo_alimento,
  coalesce(adquisicion.total, 0) as costo_adquisicion,
  coalesce(extra.gastos, 0) as gastos_extra,
  coalesce(evento.ingresos, 0) as ingresos_eventos,
  coalesce(extra.ingresos, 0) as ingresos_extra,
  coalesce(evento.unidades, 0) as unidades_producidas,
  coalesce(alimento.total, 0) + coalesce(adquisicion.total, 0) + coalesce(extra.gastos, 0) as costo_total,
  coalesce(evento.ingresos, 0) + coalesce(extra.ingresos, 0) as ingreso_total,
  coalesce(evento.ingresos, 0) + coalesce(extra.ingresos, 0) - coalesce(alimento.total, 0) - coalesce(adquisicion.total, 0) - coalesce(extra.gastos, 0) as ganancia,
  case when coalesce(alimento.total, 0) + coalesce(adquisicion.total, 0) + coalesce(extra.gastos, 0) > 0 then
    (coalesce(evento.ingresos, 0) + coalesce(extra.ingresos, 0) - coalesce(alimento.total, 0) - coalesce(adquisicion.total, 0) - coalesce(extra.gastos, 0)) /
    (coalesce(alimento.total, 0) + coalesce(adquisicion.total, 0) + coalesce(extra.gastos, 0)) * 100 end as roi_porcentaje,
  case when coalesce(evento.unidades, 0) > 0 then
    (coalesce(alimento.total, 0) + coalesce(adquisicion.total, 0) + coalesce(extra.gastos, 0)) / evento.unidades end as costo_unitario
from public.ciclos_productivos ciclo
left join lateral (select sum(precio_total) total from public.lotes_alimento where ciclo_id = ciclo.id) alimento on true
left join lateral (select sum(costo_snapshot) total from public.ciclo_costos_adquisicion where ciclo_id = ciclo.id) adquisicion on true
left join lateral (select sum(importe) filter (where tipo = 'gasto') gastos, sum(importe) filter (where tipo = 'ingreso') ingresos from public.gastos_ingresos_extra where ciclo_id = ciclo.id) extra on true
left join lateral (
  select sum(fuente.ingresos) ingresos, sum(fuente.unidades) unidades
  from (
    select sum(medicion.valor) filter (where metrica.rol = 'ingreso') ingresos,
           sum(medicion.valor) filter (where metrica.rol = 'produccion') unidades
    from public.eventos_produccion evento join public.evento_mediciones medicion on medicion.evento_id = evento.id
    join public.cat_metricas_producto metrica on metrica.id = medicion.metrica_id
    where evento.ciclo_id = ciclo.id
    union all
    select 0::numeric, sum(registro.cantidad_buena)
    from public.registros_produccion registro where registro.ciclo_id = ciclo.id
    union all
    select sum(salida.importe_total), 0::numeric
    from public.salidas_produccion salida where salida.ciclo_id = ciclo.id
  ) fuente
) evento on true;

create or replace function public.fn_punto_equilibrio(p_ciclo_id uuid, p_precio_venta numeric)
returns numeric language sql stable set search_path = public as $$
  select case when p_precio_venta is null or p_precio_venta <= 0 then null
    else greatest(costo_total - ingresos_extra, 0) / p_precio_venta end
  from public.v_ciclo_economia where ciclo_id = p_ciclo_id;
$$;

revoke all on public.v_ciclo_economia from anon;
grant select on public.v_ciclo_economia to authenticated;
revoke all on function public.fn_punto_equilibrio(uuid, numeric) from public, anon;
grant execute on function public.fn_punto_equilibrio(uuid, numeric) to authenticated;

commit;
