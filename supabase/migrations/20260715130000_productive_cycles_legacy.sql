-- Preserve and classify legacy links without guessing historical membership.
begin;

-- Only this migration may populate a missing product on an already closed row.
set local app.legacy_cycle_backfill = 'on';

create table if not exists public.migracion_ciclos_revision (
  source_table text not null,
  source_id uuid not null,
  granja_id uuid not null references public.granjas(id),
  ciclo_id uuid references public.ciclos_productivos(id),
  estado text not null check (estado in ('linked', 'unassigned', 'unresolved_membership')),
  motivo text not null,
  reviewed_at timestamptz,
  reviewed_by uuid references public.perfiles(id),
  created_at timestamptz not null default now(),
  primary key (source_table, source_id)
);

update public.ciclos_productivos ciclo
set producto_id = producto.id
from public.cat_productos producto
where ciclo.producto_id is null
  and producto.codigo = case ciclo.tipo_produccion when 'huevo' then 'huevo' when 'carne' then 'carne' end;

insert into public.migracion_ciclos_revision (source_table, source_id, granja_id, ciclo_id, estado, motivo)
select 'ciclos_productivos', ciclo.id, ciclo.granja_id, ciclo.id, 'unresolved_membership', 'Legacy cycle has no explicit member rows'
from public.ciclos_productivos ciclo
where not exists (select 1 from public.ciclo_miembros miembro where miembro.ciclo_id = ciclo.id)
on conflict (source_table, source_id) do update set granja_id = excluded.granja_id, ciclo_id = excluded.ciclo_id, estado = excluded.estado, motivo = excluded.motivo;

insert into public.migracion_ciclos_revision (source_table, source_id, granja_id, ciclo_id, estado, motivo)
select source_table, source_id, granja_id, ciclo_id,
  case when ciclo_id is null then 'unassigned' else 'linked' end,
  case when ciclo_id is null then 'No deterministic cycle link exists' else 'Existing cycle link preserved' end
from (
  select 'registros_produccion'::text source_table, id source_id, granja_id, ciclo_id from public.registros_produccion
  union all select 'salidas_produccion', id, granja_id, ciclo_id from public.salidas_produccion
  union all select 'lotes_alimento', id, granja_id, ciclo_id from public.lotes_alimento
  union all select 'gastos_ingresos_extra', id, granja_id, ciclo_id from public.gastos_ingresos_extra
) legacy
on conflict (source_table, source_id) do update set granja_id = excluded.granja_id, ciclo_id = excluded.ciclo_id, estado = excluded.estado, motivo = excluded.motivo;

alter table public.migracion_ciclos_revision enable row level security;
create policy revision_ciclos_lectura on public.migracion_ciclos_revision for select using (public.puede_leer_granja(granja_id));

create or replace function public.marcar_revision_ciclo(p_source_table text, p_source_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_revision public.migracion_ciclos_revision;
begin
  select * into v_revision from public.migracion_ciclos_revision
  where source_table = p_source_table and source_id = p_source_id for update;
  if not found or not public.puede_editar_granja(v_revision.granja_id) then raise exception 'Farm editor access required'; end if;
  update public.migracion_ciclos_revision set reviewed_at = now(), reviewed_by = auth.uid()
  where source_table = p_source_table and source_id = p_source_id;
end;
$$;

revoke all on public.migracion_ciclos_revision from anon;
revoke insert, update, delete on public.migracion_ciclos_revision from authenticated;
revoke truncate on public.migracion_ciclos_revision from authenticated;
grant select on public.migracion_ciclos_revision to authenticated;
revoke all on function public.marcar_revision_ciclo(text, uuid) from public, anon;
grant execute on function public.marcar_revision_ciclo(text, uuid) to authenticated;

commit;
