begin;

do $regression$
declare
  app_tables constant text[] := array[
    'perfiles',
    'granjas',
    'miembros_granja',
    'tipo_animal',
    'grupos',
    'cat_proposito_animal',
    'cat_razon_baja',
    'cat_tipo_adquisicion',
    'cat_alimento',
    'altas_animales',
    'bajas_animales',
    'animales',
    'cat_comida',
    'comida',
    'mezcla',
    'mezcla_comida',
    'recoleccion_huevo',
    'venta_huevo',
    'venta_animal'
  ];
  failures text[] := array[]::text[];
  app_table text;
  required_privilege text;
  test_user_id constant uuid := '00000000-0000-0000-0000-000000009901';
  visible_farm_count bigint;
begin
  if not has_schema_privilege('authenticated', 'public', 'usage') then
    failures := array_append(failures, 'authenticated_public_schema_usage');
  end if;

  foreach app_table in array app_tables loop
    foreach required_privilege in array (case
      when app_table = 'perfiles' then array['select', 'insert', 'update']
      else array['select', 'insert', 'update', 'delete']
    end) loop
      if not has_table_privilege(
        'authenticated',
        format('public.%I', app_table),
        required_privilege
      ) then
        failures := array_append(
          failures,
          format(
            'authenticated_%s_%s_privilege',
            app_table,
            required_privilege
          )
        );
      end if;
    end loop;

    if has_table_privilege(
      'anon',
      format('public.%I', app_table),
      'select'
    ) or has_table_privilege(
      'anon',
      format('public.%I', app_table),
      'insert'
    ) or has_table_privilege(
      'anon',
      format('public.%I', app_table),
      'update'
    ) or has_table_privilege(
      'anon',
      format('public.%I', app_table),
      'delete'
    ) then
      failures := array_append(failures, format('anon_%s_privileges', app_table));
    end if;

    if not (
      select c.relrowsecurity
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = app_table
    ) then
      failures := array_append(failures, format('%s_rls_disabled', app_table));
    end if;
  end loop;

  if has_table_privilege('authenticated', 'public.perfiles', 'delete') then
    failures := array_append(failures, 'authenticated_perfiles_delete_privilege');
  end if;

  if exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    join pg_catalog.pg_attribute a
      on a.attrelid = c.oid
      and a.attnum > 0
      and not a.attisdropped
    cross join lateral (
      select pg_catalog.pg_get_serial_sequence(
        format('public.%I', c.relname),
        a.attname
      ) as sequence_name
    ) owned_sequence
    where n.nspname = 'public'
      and c.relname = any(app_tables)
      and owned_sequence.sequence_name is not null
      and not has_sequence_privilege(
        'authenticated',
        owned_sequence.sequence_name,
        'usage'
      )
  ) then
    failures := array_append(failures, 'authenticated_owned_sequence_usage');
  end if;

  if exists (
    select 1
    from auth.users user_account
    left join public.perfiles profile on profile.id = user_account.id
    where profile.id is null
  ) then
    failures := array_append(failures, 'missing_auth_user_profiles');
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_trigger trigger_definition
    join pg_catalog.pg_class source_table
      on source_table.oid = trigger_definition.tgrelid
    join pg_catalog.pg_namespace source_schema
      on source_schema.oid = source_table.relnamespace
    join pg_catalog.pg_proc trigger_function
      on trigger_function.oid = trigger_definition.tgfoid
    join pg_catalog.pg_namespace function_schema
      on function_schema.oid = trigger_function.pronamespace
    where source_schema.nspname = 'auth'
      and source_table.relname = 'users'
      and trigger_definition.tgname = 'on_auth_user_created_create_profile'
      and trigger_definition.tgenabled = 'O'
      and function_schema.nspname = 'public'
      and trigger_function.proname = 'handle_new_user_profile'
      and trigger_function.prosecdef
      and trigger_function.proconfig @> array['search_path=""']
      and not has_function_privilege('public', trigger_function.oid, 'execute')
      and not has_function_privilege('anon', trigger_function.oid, 'execute')
      and not has_function_privilege('authenticated', trigger_function.oid, 'execute')
  ) then
    failures := array_append(failures, 'hardened_profile_trigger');
  end if;

  begin
    perform set_config('request.jwt.claim.sub', test_user_id::text, true);
    set local role authenticated;
    select count(*) into visible_farm_count from public.granjas;
    reset role;

    if visible_farm_count <> 0 then
      failures := array_append(failures, 'granjas_rls_filtering');
    end if;
  exception when insufficient_privilege then
    reset role;
    failures := array_append(failures, 'authenticated_granjas_reachability');
  end;

  insert into auth.users (id, aud, role, created_at, updated_at)
  values (test_user_id, 'authenticated', 'authenticated', now(), now());

  if not exists (
    select 1
    from public.perfiles profile
    where profile.id = test_user_id
      and profile.nombre = 'User'
      and profile.email is null
  ) then
    failures := array_append(failures, 'future_user_profile_provisioning');
  end if;

  if cardinality(failures) > 0 then
    raise exception 'Regression failures: %', array_to_string(failures, ', ');
  end if;
end;
$regression$;

rollback;
