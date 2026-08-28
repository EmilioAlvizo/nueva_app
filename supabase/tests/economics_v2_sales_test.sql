begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then raise exception '%', message; end if;
end;
$$;

select pg_temp.assert_true(
  exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'venta_animal' and column_name in ('baja_id', 'record_kind', 'quantity', 'total_amount')),
  'venta_animal must carry canonical sale linkage, kind, quantity, and total'
);

select pg_temp.assert_true(
  exists (select 1 from pg_constraint where conrelid = 'public.venta_animal'::regclass and contype = 'u' and pg_get_constraintdef(oid) like '%baja_id%')
  and exists (select 1 from pg_constraint where conrelid = 'public.venta_animal'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%legacy_batch%' and pg_get_constraintdef(oid) like '%animal_id%'),
  'only one exact-total legacy batch sale may link each baja'
);

select pg_temp.assert_true(
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'registrar_venta_animal_v2' and not p.prosecdef),
  'the sale API must remain a security-invoker wrapper'
);

do $sales$
<<sales>>
declare
  editor_id uuid := '00000000-0000-0000-0000-000000001101';
  farm_id uuid := '00000000-0000-0000-0000-000000001201';
  type_id uuid := '00000000-0000-0000-0000-000000001301';
  reason_id uuid := '00000000-0000-0000-0000-000000001401';
  animal_1 uuid := '00000000-0000-0000-0000-000000001501';
  animal_2 uuid := '00000000-0000-0000-0000-000000001502';
  animal_3 uuid := '00000000-0000-0000-0000-000000001503';
  cycle_id uuid := '00000000-0000-0000-0000-000000001601';
  legacy_baja uuid := '00000000-0000-0000-0000-000000001701';
  sale_id uuid;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values (editor_id, 'authenticated', 'authenticated', 'economics-v2-editor-sales@example.test', now(), now());
  insert into public.perfiles (id, nombre) values (editor_id, 'Editor')
  on conflict (id) do update set nombre = excluded.nombre;
  insert into public.granjas (id, owner_id, nombre, created_by) values (farm_id, editor_id, 'Farm', editor_id);
  insert into public.tipo_animal (id, granja_id, nombre, created_by) values (type_id, farm_id, 'Bird', editor_id);
  insert into public.cat_razon_baja (id, nombre, genera_ingreso) values (reason_id, 'Sale', true);
  insert into public.animales (id, granja_id, tipo_animal_id, fecha_adquisicion, created_by)
  values (animal_1, farm_id, type_id, current_date - 5, editor_id), (animal_2, farm_id, type_id, current_date - 5, editor_id), (animal_3, farm_id, type_id, current_date - 5, editor_id);
  insert into economics_v2.feature_flags values (farm_id, true);
  insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, created_by)
  select cycle_id, farm_id, id, current_date - 1, editor_id from public.cat_proposito_animal where codigo_calculo = 'carne' limit 1;
  insert into economics_v2.cycle_animals values (cycle_id, animal_1, current_date - 1, null, null), (cycle_id, animal_2, current_date - 1, null, null);

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  begin
    perform public.registrar_venta_animal_v2(farm_id, array[animal_1], current_date, -1, null, null);
    raise exception 'invalid sale total must force a rollback';
  exception when check_violation or invalid_parameter_value then null;
  end;
  reset role;
  perform pg_temp.assert_true(
    (select count(*) = 0 from public.venta_animal where animal_id = animal_1)
    and (select activo from public.animales where id = animal_1)
    and (select ca.left_on is null from economics_v2.cycle_animals ca where ca.cycle_id = sales.cycle_id and ca.animal_id = animal_1),
    'a failed sale must roll back sale, baja, status, and membership changes'
  );

  set local role authenticated;
  select public.registrar_venta_animal_v2(farm_id, array[animal_1], current_date, 30, null, 'partial') into sale_id;
  reset role;
  perform pg_temp.assert_true(
    (select total_amount = 30 and quantity = 1 from public.venta_animal where id = sale_id)
    and (select not activo from public.animales where id = animal_1)
    and (select ca.left_on = current_date and ca.sold_by_sale_id = sale_id from economics_v2.cycle_animals ca where ca.cycle_id = sales.cycle_id and ca.animal_id = animal_1)
    and (select activo from public.animales where id = animal_2),
    'partial sales must close only sold memberships and use canonical revenue'
  );

  insert into public.bajas_animales (id, granja_id, tipo_animal_id, razon_baja_id, fecha_baja, cantidad_animales, importe_total, created_by)
  values (legacy_baja, farm_id, type_id, reason_id, current_date - 2, 2, 44, editor_id);
  perform economics_v2.canonicalize_legacy_sales_impl();
  perform economics_v2.canonicalize_legacy_sales_impl();
  perform pg_temp.assert_true(
    (select count(*) = 1 from public.venta_animal where baja_id = legacy_baja and record_kind = 'legacy_batch' and quantity = 2 and total_amount = 44)
    and (select coalesce(sum(total_amount), 0) = 44 from public.venta_animal where baja_id = legacy_baja)
    and (select importe_total = 44 from public.bajas_animales where id = legacy_baja),
    'legacy batch canonicalization must be idempotent and never add baja revenue'
  );
end;
$sales$;

rollback;
