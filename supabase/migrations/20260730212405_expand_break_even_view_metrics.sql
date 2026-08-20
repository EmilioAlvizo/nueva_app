create index if not exists idx_mezcla_grupo_fecha_inicio
  on public.mezcla (grupo_id, fecha_inicio, id);

create index if not exists idx_animales_grupo_fecha_adquisicion
  on public.animales (grupo_id, fecha_adquisicion);

create index if not exists idx_animales_baja_id
  on public.animales (baja_id)
  where baja_id is not null;

create or replace view public.puntos_equilibrio_huevos
with (security_invoker = true)
as
with mixture_windows as (
  select
    m.id as mezcla_id,
    m.granja_id,
    m.grupo_id,
    g.nombre as grupo_nombre,
    m.fecha_inicio,
    m.fecha_termino,
    lead(m.fecha_inicio) over (
      partition by m.grupo_id
      order by m.fecha_inicio, m.id
    ) as siguiente_inicio
  from public.mezcla m
  join public.grupos g on g.id = m.grupo_id
), periods as (
  select
    mw.*,
    coalesce(
      mw.fecha_termino,
      mw.siguiente_inicio,
      current_date
    ) as fecha_fin_calculada,
    case
      when mw.fecha_termino is null and mw.siguiente_inicio is null
        then current_date + 1
      else coalesce(
        mw.fecha_termino,
        mw.siguiente_inicio,
        current_date
      )
    end as fecha_fin_exclusiva
  from mixture_windows mw
), aggregates as (
  select
    p.*,
    greatest(p.fecha_fin_exclusiva - p.fecha_inicio, 1) as dias_mezcla,
    coalesce((
      select sum(r.buenos)
      from public.recoleccion_huevo r
      where r.grupo_id = p.grupo_id
        and r.fecha_recoleccion >= p.fecha_inicio
        and r.fecha_recoleccion < p.fecha_fin_exclusiva
    ), 0::bigint) as buenos,
    coalesce((
      select sum(r.rotos)
      from public.recoleccion_huevo r
      where r.grupo_id = p.grupo_id
        and r.fecha_recoleccion >= p.fecha_inicio
        and r.fecha_recoleccion < p.fecha_fin_exclusiva
    ), 0::bigint) as rotos,
    coalesce((
      select sum(coalesce(mc.cantidad, c.cantidad))
      from public.mezcla_comida mc
      join public.comida c on c.id = mc.comida_id
      where mc.mezcla_id = p.mezcla_id
    ), 0::numeric) as consumo_total,
    coalesce((
      select sum(
        case
          when c.cantidad > 0
            then coalesce(c.precio, 0::numeric)
              * coalesce(mc.cantidad, c.cantidad)
              / c.cantidad
          else 0::numeric
        end
      )
      from public.mezcla_comida mc
      join public.comida c on c.id = mc.comida_id
      where mc.mezcla_id = p.mezcla_id
    ), 0::numeric) as total_costo_comidas,
    coalesce((
      select sum(
        greatest(
          least(
            coalesce(b.fecha_baja, p.fecha_fin_exclusiva),
            p.fecha_fin_exclusiva
          ) - greatest(a.fecha_adquisicion, p.fecha_inicio),
          0
        )
      )::numeric
      from public.animales a
      left join public.bajas_animales b on b.id = a.baja_id
      where a.grupo_id = p.grupo_id
        and a.fecha_adquisicion < p.fecha_fin_exclusiva
        and (b.fecha_baja is null or b.fecha_baja > p.fecha_inicio)
    ), 0::numeric) as ave_dias,
    (
      select sum(v.precio * v.cantidad) / nullif(sum(v.cantidad), 0)
      from public.venta_huevo v
      where v.grupo_id = p.grupo_id
        and v.fecha_venta >= p.fecha_inicio
        and v.fecha_venta < p.fecha_fin_exclusiva
    ) as precio_venta_promedio
  from periods p
), base_metrics as (
  select
    a.*,
    a.total_costo_comidas / nullif(a.buenos, 0) as punto_de_equilibrio,
    a.ave_dias / a.dias_mezcla as aves_promedio_ponderado,
    a.buenos::numeric / a.dias_mezcla as huevos_por_dia,
    a.consumo_total / a.dias_mezcla as consumo_por_dia
  from aggregates a
), final_metrics as (
  select
    b.*,
    b.huevos_por_dia / nullif(b.aves_promedio_ponderado, 0)
      as huevos_por_dia_ave,
    b.consumo_por_dia / nullif(b.aves_promedio_ponderado, 0)
      as consumo_por_dia_ave,
    (b.precio_venta_promedio - b.punto_de_equilibrio)
      / nullif(b.punto_de_equilibrio, 0) * 100
      as margen_porcentaje
  from base_metrics b
)
select
  fecha_inicio,
  fecha_termino,
  mezcla_id,
  grupo_nombre,
  buenos,
  rotos,
  total_costo_comidas,
  punto_de_equilibrio,
  granja_id,
  grupo_id,
  fecha_fin_calculada,
  dias_mezcla,
  consumo_total,
  aves_promedio_ponderado,
  huevos_por_dia,
  huevos_por_dia_ave,
  consumo_por_dia,
  consumo_por_dia_ave,
  precio_venta_promedio,
  margen_porcentaje
from final_metrics
order by fecha_inicio;

comment on view public.puntos_equilibrio_huevos is
  'Farm-scoped egg break-even metrics. Weighted birds = bird-days divided by mixture days. Closed periods are half-open; active periods include the current date.';
comment on column public.puntos_equilibrio_huevos.aves_promedio_ponderado is
  'Time-weighted average bird count: sum of each bird active days divided by mixture days.';
comment on column public.puntos_equilibrio_huevos.margen_porcentaje is
  'Percentage margin between quantity-weighted unit egg sale price and break-even price.';

revoke all privileges on table public.puntos_equilibrio_huevos from public;
revoke all privileges on table public.puntos_equilibrio_huevos from anon;
grant select on table public.puntos_equilibrio_huevos to authenticated;
grant select on table public.puntos_equilibrio_huevos to service_role;