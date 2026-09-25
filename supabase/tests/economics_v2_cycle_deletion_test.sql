begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then
    raise exception '%', message;
  end if;
end;
$$;

select pg_temp.assert_true(
  to_regprocedure('public.eliminar_ciclo_v2(uuid,uuid)') is not null,
  'Cycle deletion must expose the exact farm-scoped signature'
);

select pg_temp.assert_true(
  (select not procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated', procedure.oid, 'execute')
      and not has_function_privilege('anon', procedure.oid, 'execute')
      and not exists (
        select 1
        from aclexplode(coalesce(
          procedure.proacl,
          acldefault('f', procedure.proowner)
        )) privilege
        where privilege.grantee = 0
          and privilege.privilege_type = 'EXECUTE'
      )
   from pg_proc procedure
   where procedure.oid = to_regprocedure(
     'public.eliminar_ciclo_v2(uuid,uuid)'
   )),
  'Cycle deletion wrapper must be a fixed-path invoker granted only to authenticated'
);

select pg_temp.assert_true(
  (select procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated', procedure.oid, 'execute')
      and not has_function_privilege('anon', procedure.oid, 'execute')
      and not exists (
        select 1
        from aclexplode(coalesce(
          procedure.proacl,
          acldefault('f', procedure.proowner)
        )) privilege
        where privilege.grantee = 0
          and privilege.privilege_type = 'EXECUTE'
      )
   from pg_proc procedure
   where procedure.oid = to_regprocedure(
     'economics_v2.delete_cycle_impl(uuid,uuid)'
   )),
  'Cycle deletion implementation must be a fixed-path definer unavailable to anon and PUBLIC'
);

select pg_temp.assert_true(
  exists (
    select 1
    from pg_constraint constraint_definition
    where constraint_definition.conrelid = 'economics_v2.final_results'::regclass
      and constraint_definition.contype = 'f'
      and constraint_definition.confrelid = 'economics_v2.cycles'::regclass
      and constraint_definition.confdeltype = 'c'
  ),
  'Final results must cascade only as part of parent cycle deletion'
);

do $cycle_deletion$
<<cycle_deletion>>
declare
  owner_id uuid := '00000000-0000-0000-0000-00000000d101';
  editor_id uuid := '00000000-0000-0000-0000-00000000d102';
  viewer_id uuid := '00000000-0000-0000-0000-00000000d103';
  outsider_id uuid := '00000000-0000-0000-0000-00000000d104';
  farm_id uuid := '00000000-0000-0000-0000-00000000d201';
  foreign_farm_id uuid := '00000000-0000-0000-0000-00000000d202';
  type_id uuid := '00000000-0000-0000-0000-00000000d301';
  group_id uuid := '00000000-0000-0000-0000-00000000d401';
  animal_id uuid := '00000000-0000-0000-0000-00000000d501';
  mixture_id uuid := '00000000-0000-0000-0000-00000000d601';
  baja_id uuid := '00000000-0000-0000-0000-00000000d701';
  sale_id uuid := '00000000-0000-0000-0000-00000000d702';
  egg_collection_id uuid := '00000000-0000-0000-0000-00000000d703';
  egg_sale_id uuid := '00000000-0000-0000-0000-00000000d704';
  owner_cycle_id uuid := '00000000-0000-0000-0000-00000000d801';
  editor_cycle_id uuid := '00000000-0000-0000-0000-00000000d802';
  production_closed_cycle_id uuid := '00000000-0000-0000-0000-00000000d803';
  settled_cycle_id uuid := '00000000-0000-0000-0000-00000000d804';
  foreign_cycle_id uuid := '00000000-0000-0000-0000-00000000d805';
  purpose_id uuid;
  reason_id uuid;
  deleted_cycle_id uuid;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (owner_id, 'authenticated', 'authenticated', 'cycle-delete-owner@example.test', now(), now()),
    (editor_id, 'authenticated', 'authenticated', 'cycle-delete-editor@example.test', now(), now()),
    (viewer_id, 'authenticated', 'authenticated', 'cycle-delete-viewer@example.test', now(), now()),
    (outsider_id, 'authenticated', 'authenticated', 'cycle-delete-outsider@example.test', now(), now());
  insert into public.perfiles (id, nombre)
  values
    (owner_id, 'Cycle delete owner'),
    (editor_id, 'Cycle delete editor'),
    (viewer_id, 'Cycle delete viewer'),
    (outsider_id, 'Cycle delete outsider')
  on conflict (id) do update set nombre = excluded.nombre;
  insert into public.granjas (id, owner_id, nombre, created_by)
  values
    (farm_id, owner_id, 'Cycle delete farm', owner_id),
    (foreign_farm_id, outsider_id, 'Foreign cycle delete farm', outsider_id);
  insert into public.miembros_granja (granja_id, user_id, rol, invited_by)
  values
    (farm_id, editor_id, 'editor', owner_id),
    (farm_id, viewer_id, 'viewer', owner_id);
  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled)
  values (farm_id, true), (foreign_farm_id, true);

  select id into purpose_id
  from public.cat_proposito_animal
  where codigo_calculo = 'postura'
  order by id
  limit 1;
  select id into reason_id
  from public.cat_razon_baja
  where genera_ingreso and activo
  order by id
  limit 1;
  if reason_id is null then
    insert into public.cat_razon_baja (nombre, genera_ingreso, activo)
    values ('Cycle deletion sale', true, true)
    returning id into reason_id;
  end if;

  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_id, farm_id, 'Cycle deletion bird', owner_id);
  insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
  values (group_id, farm_id, type_id, 'Cycle deletion group', owner_id);
  insert into public.animales (
    id, granja_id, tipo_animal_id, grupo_id, proposito_id,
    fecha_adquisicion, created_by
  ) values (
    animal_id, farm_id, type_id, group_id, purpose_id,
    current_date - 20, owner_id
  );
  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values (mixture_id, farm_id, group_id, current_date - 10, owner_id);
  insert into public.bajas_animales (
    id, granja_id, tipo_animal_id, razon_baja_id, fecha_baja,
    cantidad_animales, importe_total, created_by
  ) values (
    baja_id, farm_id, type_id, reason_id, current_date - 2,
    1, 25, owner_id
  );
  insert into public.venta_animal (
    id, granja_id, tipo_animal_id, animal_id, fecha_venta, created_by,
    baja_id, record_kind, quantity, total_amount
  ) values (
    sale_id, farm_id, type_id, animal_id, current_date - 2, owner_id,
    baja_id, 'individual', 1, 25
  );
  insert into public.recoleccion_huevo (
    id, granja_id, grupo_id, fecha_recoleccion, buenos, rotos, created_by
  ) values (
    egg_collection_id, farm_id, group_id, current_date - 3, 10, 1, owner_id
  );
  insert into public.venta_huevo (
    id, granja_id, grupo_id, fecha_venta, cantidad, precio, created_by
  ) values (
    egg_sale_id, farm_id, group_id, current_date - 2, 5, 2, owner_id
  );

  insert into economics_v2.cycles (
    id, granja_id, proposito_id, starts_on, status, created_by
  ) values
    (owner_cycle_id, farm_id, purpose_id, current_date - 10, 'open', owner_id),
    (editor_cycle_id, farm_id, purpose_id, current_date - 9, 'open', editor_id);
  insert into economics_v2.cycles (
    id, granja_id, proposito_id, starts_on, ends_on,
    production_closed_on, status, created_by
  ) values (
    production_closed_cycle_id, farm_id, purpose_id, current_date - 8,
    current_date - 1, current_date - 2, 'production_closed', owner_id
  );
  insert into economics_v2.cycles (
    id, granja_id, proposito_id, starts_on, ends_on,
    production_closed_on, settled_on, status, created_by
  ) values (
    settled_cycle_id, farm_id, purpose_id, current_date - 8,
    current_date - 1, current_date - 2, current_date - 1,
    'settled', owner_id
  );
  insert into economics_v2.cycles (
    id, granja_id, proposito_id, starts_on, status, created_by
  ) values (
    foreign_cycle_id, foreign_farm_id, purpose_id, current_date - 7,
    'open', outsider_id
  );

  insert into economics_v2.cycle_animals (
    cycle_id, animal_id, joined_on, left_on, sold_by_sale_id
  ) values (
    owner_cycle_id, animal_id, current_date - 10, current_date - 2, sale_id
  );
  insert into economics_v2.cycle_expenses (
    cycle_id, granja_id, occurred_on, amount, created_by
  ) values (owner_cycle_id, farm_id, current_date - 4, 12, owner_id);
  insert into economics_v2.cycle_feeds (
    cycle_id, granja_id, mezcla_id, starts_on, created_by
  ) values (owner_cycle_id, farm_id, mixture_id, current_date - 10, owner_id);
  insert into economics_v2.projections (
    cycle_id, granja_id, assumptions, result_snapshot, created_by
  ) values (
    owner_cycle_id, farm_id, '{}'::jsonb, '{}'::jsonb, owner_id
  );
  insert into economics_v2.final_results (
    cycle_id, granja_id, calculation_version,
    input_snapshot, result_snapshot, created_by
  ) values (
    settled_cycle_id, farm_id, 'v2', '{}'::jsonb, '{}'::jsonb, owner_id
  );

  begin
    delete from economics_v2.final_results
    where cycle_id = settled_cycle_id;
    raise exception 'ordinary final-result deletion must remain rejected';
  exception when check_violation then null;
  end;

  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  set local role authenticated;
  begin
    perform public.eliminar_ciclo_v2(farm_id, owner_cycle_id);
    raise exception 'viewer deletion must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', outsider_id::text, true);
  set local role authenticated;
  begin
    perform public.eliminar_ciclo_v2(farm_id, owner_cycle_id);
    raise exception 'outsider deletion must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;
  begin
    perform public.eliminar_ciclo_v2(farm_id, foreign_cycle_id);
    raise exception 'cross-farm deletion must be rejected';
  exception when no_data_found then null;
  end;
  reset role;

  set local role anon;
  begin
    perform public.eliminar_ciclo_v2(farm_id, owner_cycle_id);
    raise exception 'anonymous deletion must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;
  select public.eliminar_ciclo_v2(farm_id, owner_cycle_id)
  into deleted_cycle_id;
  reset role;

  perform pg_temp.assert_true(
    deleted_cycle_id = owner_cycle_id
    and not exists (
      select 1 from economics_v2.cycles where id = owner_cycle_id
    )
    and not exists (
      select 1 from economics_v2.cycle_animals where cycle_id = owner_cycle_id
    )
    and not exists (
      select 1 from economics_v2.cycle_expenses where cycle_id = owner_cycle_id
    )
    and not exists (
      select 1 from economics_v2.cycle_feeds where cycle_id = owner_cycle_id
    )
    and not exists (
      select 1 from economics_v2.projections where cycle_id = owner_cycle_id
    )
    and exists (select 1 from public.animales where id = animal_id)
    and exists (select 1 from public.mezcla where id = mixture_id)
    and exists (select 1 from public.bajas_animales where id = baja_id)
    and exists (select 1 from public.venta_animal where id = sale_id)
    and exists (
      select 1 from public.recoleccion_huevo where id = egg_collection_id
    )
    and exists (select 1 from public.venta_huevo where id = egg_sale_id),
    'Populated open deletion must remove only cycle-owned history'
  );

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  perform public.eliminar_ciclo_v2(farm_id, editor_cycle_id);
  perform public.eliminar_ciclo_v2(farm_id, production_closed_cycle_id);
  perform public.eliminar_ciclo_v2(farm_id, settled_cycle_id);
  reset role;

  perform pg_temp.assert_true(
    not exists (
      select 1
      from economics_v2.cycles
      where id in (
        editor_cycle_id,
        production_closed_cycle_id,
        settled_cycle_id
      )
    )
    and not exists (
      select 1
      from economics_v2.final_results
      where cycle_id = settled_cycle_id
    )
    and exists (
      select 1 from economics_v2.cycles where id = foreign_cycle_id
    ),
    'Editor must delete empty open, production-closed, and settled cycles including snapshots'
  );
end;
$cycle_deletion$;

rollback;
