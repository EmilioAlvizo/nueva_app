-- ============ FUNCIONES HELPER (security definer para evitar recursion en RLS) ============

create or replace function public.fn_es_miembro_granja(p_granja_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.miembros_granja
    where granja_id = p_granja_id and user_id = auth.uid()
  );
$$;

create or replace function public.fn_puede_editar_granja(p_granja_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.miembros_granja
    where granja_id = p_granja_id and user_id = auth.uid()
      and rol in ('owner', 'editor')
  );
$$;

create or replace function public.fn_es_owner_granja(p_granja_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.miembros_granja
    where granja_id = p_granja_id and user_id = auth.uid()
      and rol = 'owner'
  );
$$;

-- ============ ENABLE RLS ============
alter table public.perfiles enable row level security;
alter table public.granjas enable row level security;
alter table public.miembros_granja enable row level security;
alter table public.tipo_animal enable row level security;
alter table public.grupos enable row level security;
alter table public.altas_animales enable row level security;
alter table public.bajas_animales enable row level security;
alter table public.animales enable row level security;
alter table public.comida enable row level security;
alter table public.mezcla enable row level security;
alter table public.mezcla_comida enable row level security;
alter table public.recoleccion_huevo enable row level security;
alter table public.venta_huevo enable row level security;
alter table public.venta_animal enable row level security;
alter table public.cat_proposito_animal enable row level security;
alter table public.cat_razon_baja enable row level security;
alter table public.cat_tipo_adquisicion enable row level security;
alter table public.cat_alimento enable row level security;
alter table public.cat_comida enable row level security;

-- ============ POLICIES: GRANJAS ============
create policy granjas_select_miembros on public.granjas for select
  using (public.fn_es_miembro_granja(id));

create policy granjas_insert_propio on public.granjas for insert
  with check (owner_id = auth.uid());

create policy granjas_update_owner on public.granjas for update
  using (public.fn_es_owner_granja(id))
  with check (public.fn_es_owner_granja(id));

create policy granjas_delete_owner on public.granjas for delete
  using (public.fn_es_owner_granja(id));

-- ============ POLICIES: MIEMBROS_GRANJA ============
create policy miembros_granja_select_miembros on public.miembros_granja for select
  using (public.fn_es_miembro_granja(granja_id));

create policy miembros_granja_insert_owner on public.miembros_granja for insert
  with check (public.fn_es_owner_granja(granja_id));

create policy miembros_granja_update_owner on public.miembros_granja for update
  using (public.fn_es_owner_granja(granja_id))
  with check (public.fn_es_owner_granja(granja_id));

create policy miembros_granja_delete_owner on public.miembros_granja for delete
  using (public.fn_es_owner_granja(granja_id));

-- ============ POLICIES: PERFILES ============
create policy perfiles_select_propio_o_compartido on public.perfiles for select
  using (
    id = auth.uid()
    or exists (
      select 1 from public.miembros_granja m
      where m.user_id = perfiles.id
        and public.fn_es_miembro_granja(m.granja_id)
    )
  );

create policy perfiles_insert_propio on public.perfiles for insert
  with check (id = auth.uid());

create policy perfiles_update_propio on public.perfiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- ============ POLICIES: TABLAS DE DATOS (granja_id not null) ============
-- select: cualquier miembro (owner/editor/viewer); insert/update/delete: owner o editor
do $$
declare
  t text;
begin
  foreach t in array array[
    'tipo_animal','grupos','altas_animales','bajas_animales','animales',
    'comida','mezcla','mezcla_comida','recoleccion_huevo','venta_huevo','venta_animal'
  ]
  loop
    execute format('create policy %I on public.%I for select using (public.fn_es_miembro_granja(granja_id));', t || '_select_miembros', t);
    execute format('create policy %I on public.%I for insert with check (public.fn_puede_editar_granja(granja_id));', t || '_insert_editor', t);
    execute format('create policy %I on public.%I for update using (public.fn_puede_editar_granja(granja_id)) with check (public.fn_puede_editar_granja(granja_id));', t || '_update_editor', t);
    execute format('create policy %I on public.%I for delete using (public.fn_puede_editar_granja(granja_id));', t || '_delete_editor', t);
  end loop;
end $$;

-- ============ POLICIES: CATALOGOS (granja_id nullable = catalogo global) ============
-- select: global (granja_id null) o miembro de esa granja; insert/update/delete: solo dentro de una granja donde seas owner/editor
do $$
declare
  t text;
begin
  foreach t in array array[
    'cat_proposito_animal','cat_razon_baja','cat_tipo_adquisicion','cat_alimento','cat_comida'
  ]
  loop
    execute format('create policy %I on public.%I for select using (granja_id is null or public.fn_es_miembro_granja(granja_id));', t || '_select_miembros', t);
    execute format('create policy %I on public.%I for insert with check (granja_id is not null and public.fn_puede_editar_granja(granja_id));', t || '_insert_editor', t);
    execute format('create policy %I on public.%I for update using (granja_id is not null and public.fn_puede_editar_granja(granja_id)) with check (granja_id is not null and public.fn_puede_editar_granja(granja_id));', t || '_update_editor', t);
    execute format('create policy %I on public.%I for delete using (granja_id is not null and public.fn_puede_editar_granja(granja_id));', t || '_delete_editor', t);
  end loop;
end $$;
