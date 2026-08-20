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
  to_regnamespace('economics_v2') is not null,
  'economics_v2 private schema must exist'
);

select pg_temp.assert_true(
  has_schema_privilege('authenticated', 'economics_v2', 'usage')
  and not has_schema_privilege('anon', 'economics_v2', 'usage')
  and not has_schema_privilege('public', 'economics_v2', 'usage'),
  'only authenticated may use the private implementation schema'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'economics_v2'
      and c.relkind = 'r'
      and (has_table_privilege('authenticated', c.oid, 'select,insert,update,delete')
        or has_table_privilege('anon', c.oid, 'select,insert,update,delete'))
  ),
  'public roles must not receive private table access'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_constraint fk
    join pg_class table_class on table_class.oid = fk.conrelid
    join pg_namespace table_schema on table_schema.oid = table_class.relnamespace
    where fk.contype = 'f'
      and table_schema.nspname = 'economics_v2'
      and not exists (
        select 1
        from pg_index index_definition
        where index_definition.indrelid = fk.conrelid
          and index_definition.indpred is null
          and index_definition.indkey::smallint[] @> fk.conkey
      )
  ),
  'every V2 foreign key must have a covering non-partial index'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and p.proname like '%v2%'
  ),
  'public V2 APIs must remain security invoker'
);

select pg_temp.assert_true(
  exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'economics_v2' and p.proname = 'record_animal_sale_impl'
      and p.prosecdef and p.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated', p.oid, 'execute')
      and not has_function_privilege('anon', p.oid, 'execute')
      and not has_function_privilege('public', p.oid, 'execute')
  ),
  'only authenticated may execute the hardened private sale implementation'
);

select pg_temp.assert_true(
  exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'economics_v2_cycle_economics'
      and c.relkind = 'v' and c.reloptions @> array['security_invoker=true']
  ),
  'the public economics view must be security invoker'
);

do $security$
declare
  editor_id uuid := '00000000-0000-0000-0000-000000000101';
  viewer_id uuid := '00000000-0000-0000-0000-000000000102';
  farm_a uuid := '00000000-0000-0000-0000-000000000201';
  farm_b uuid := '00000000-0000-0000-0000-000000000202';
  type_a uuid := '00000000-0000-0000-0000-000000000301';
  reason_a uuid := '00000000-0000-0000-0000-000000000401';
  animal_a uuid := '00000000-0000-0000-0000-000000000501';
  animal_b uuid := '00000000-0000-0000-0000-000000000502';
  cycle_a uuid := '00000000-0000-0000-0000-000000000601';
  sale_id uuid;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (editor_id, 'authenticated', 'authenticated', 'economics-v2-editor-security@example.test', now(), now()),
    (viewer_id, 'authenticated', 'authenticated', 'economics-v2-viewer-security@example.test', now(), now());
  insert into public.perfiles (id, nombre) values (editor_id, 'Editor'), (viewer_id, 'Viewer');
  insert into public.granjas (id, owner_id, nombre, created_by)
  values (farm_a, editor_id, 'A', editor_id), (farm_b, editor_id, 'B', editor_id);
  insert into public.miembros_granja (granja_id, user_id, rol)
  values (farm_a, viewer_id, 'viewer');
  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_a, farm_a, 'Hen', editor_id);
  insert into public.cat_razon_baja (id, nombre, genera_ingreso)
  values (reason_a, 'Sale', true);
  insert into public.animales (id, granja_id, tipo_animal_id, fecha_adquisicion, created_by)
  values (animal_a, farm_a, type_a, current_date - 5, editor_id),
         (animal_b, farm_b, type_a, current_date - 5, editor_id);
  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled) values (farm_a, true);
  insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, created_by)
  select cycle_a, farm_a, p.id, current_date - 1, editor_id
  from public.cat_proposito_animal p where p.codigo_calculo = 'carne' limit 1;
  insert into economics_v2.cycle_animals (cycle_id, animal_id, joined_on)
  values (cycle_a, animal_a, current_date - 1);

  begin
    perform economics_v2.record_animal_sale_impl(farm_a, array[animal_a], current_date, 10, null, null);
    raise exception 'null auth must be rejected by the private definer';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  set local role authenticated;
  begin
    perform 1 from economics_v2.cycles;
    raise exception 'authenticated direct private-table reads must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.registrar_venta_animal_v2(farm_a, array[animal_a], current_date, 10, null, null);
    raise exception 'viewer mutation must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  begin
    perform public.registrar_venta_animal_v2(farm_a, array[animal_b], current_date, 10, null, null);
    raise exception 'cross-farm sale must be rejected';
  exception when insufficient_privilege or foreign_key_violation then null;
  end;
  set local search_path = pg_temp, public;
  select public.registrar_venta_animal_v2(farm_a, array[animal_a], current_date, 10, null, null) into sale_id;
  reset role;

  perform pg_temp.assert_true(sale_id is not null, 'authenticated editor must complete the public wrapper flow');
  perform pg_temp.assert_true(
    (select count(*) = 1 from public.venta_animal where id = sale_id),
    'hostile caller search_path must not redirect private objects'
  );
end;
$security$;

rollback;
