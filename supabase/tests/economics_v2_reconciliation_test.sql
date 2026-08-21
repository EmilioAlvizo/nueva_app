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
  (
    select array_agg(
      case
        when left(name, 15) = version || '_' then name
        else version || '_' || name
      end
      order by version
    )
    from supabase_migrations.schema_migrations
  ) = array[
    '20260716185716_initial_schema_gallinas2',
    '20260716203237_add_comida_mezcla_huevos_venta_tables',
    '20260716203742_rls_policies_owner_editor_viewer',
    '20260717190444_food_module_mixtures_categories_crud_direct',
    '20260724200310_enforce_baja_temporal_consistency',
    '20260730212405_expand_break_even_view_metrics',
    '20260730212510_restrict_break_even_view_privileges',
    '20260802030239_create_app_release_delivery',
    '20260817011421_economics_v2_schema',
    '20260821130000_economics_v2_lifecycle_apis'
  ]::text[],
  'the disposable sandbox must contain only the ordered repository migration identity'
);

select pg_temp.assert_true(
  position(
    'bajas_animales' in pg_get_functiondef(
      'economics_v2.calculate_cycle_impl(uuid,uuid)'::regprocedure
    )
  ) = 0,
  'V2 calculation must not derive revenue from administrative bajas_animales'
);

do $reconciliation$
<<reconciliation>>
declare
  editor_id uuid := '00000000-0000-0000-0000-000000009101';
  farm_id uuid := '00000000-0000-0000-0000-000000009201';
  type_id uuid := '00000000-0000-0000-0000-000000009301';
  reason_id uuid := '00000000-0000-0000-0000-000000009401';
  baja_id uuid := '00000000-0000-0000-0000-000000009501';
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values (editor_id, 'authenticated', 'authenticated', 'economics-v2-reconciliation@example.test', now(), now());
  insert into public.perfiles (id, nombre) values (editor_id, 'Reconciliation editor');
  insert into public.granjas (id, owner_id, nombre, created_by)
  values (farm_id, editor_id, 'Reconciliation farm', editor_id);
  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_id, farm_id, 'Reconciliation bird', editor_id);
  insert into public.cat_razon_baja (id, nombre, genera_ingreso)
  values (reason_id, 'Historical sale', true);
  insert into public.bajas_animales (
    id, granja_id, tipo_animal_id, razon_baja_id, fecha_baja,
    cantidad_animales, importe_total, created_by
  ) values (
    baja_id, farm_id, type_id, reason_id, current_date - 1,
    2, 44, editor_id
  );

  perform economics_v2.canonicalize_legacy_sales_impl();
  perform economics_v2.canonicalize_legacy_sales_impl();

  perform pg_temp.assert_true(
    (select count(*) = 1 from public.venta_animal where public.venta_animal.baja_id = reconciliation.baja_id)
    and (select count(*) = 1 from public.venta_animal where public.venta_animal.baja_id = reconciliation.baja_id and record_kind = 'legacy_batch')
    and (select total_amount = 44 and quantity = 2 from public.venta_animal where public.venta_animal.baja_id = reconciliation.baja_id)
    and (select coalesce(sum(total_amount), 0) = 44 from public.venta_animal where public.venta_animal.baja_id = reconciliation.baja_id)
    and (select importe_total = 44 from public.bajas_animales where id = reconciliation.baja_id),
    'canonicalization must preserve the exact baja total, unique origin link, and idempotent row count'
  );
end;
$reconciliation$;

rollback;
