grant usage on schema public to authenticated;

grant select, insert, update on table public.perfiles to authenticated;

grant select, insert, update, delete on table
  public.granjas,
  public.miembros_granja,
  public.tipo_animal,
  public.grupos,
  public.cat_proposito_animal,
  public.cat_razon_baja,
  public.cat_tipo_adquisicion,
  public.cat_alimento,
  public.altas_animales,
  public.bajas_animales,
  public.animales,
  public.cat_comida,
  public.comida,
  public.mezcla,
  public.mezcla_comida,
  public.recoleccion_huevo,
  public.venta_huevo,
  public.venta_animal
to authenticated;

do $grant_owned_sequences$
declare
  sequence_name text;
begin
  for sequence_name in
    select distinct pg_catalog.pg_get_serial_sequence(
      format('public.%I', table_class.relname),
      column_definition.attname
    )
    from pg_catalog.pg_class table_class
    join pg_catalog.pg_namespace table_schema
      on table_schema.oid = table_class.relnamespace
    join pg_catalog.pg_attribute column_definition
      on column_definition.attrelid = table_class.oid
      and column_definition.attnum > 0
      and not column_definition.attisdropped
    where table_schema.nspname = 'public'
      and table_class.relname in (
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
      )
      and pg_catalog.pg_get_serial_sequence(
        format('public.%I', table_class.relname),
        column_definition.attname
      ) is not null
  loop
    execute format('grant usage on sequence %s to authenticated', sequence_name);
  end loop;
end;
$grant_owned_sequences$;

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.perfiles (id, nombre, email)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
      'User'
    ),
    nullif(btrim(new.email), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke execute on function public.handle_new_user_profile()
from public, anon, authenticated;

drop trigger if exists on_auth_user_created_create_profile on auth.users;

create trigger on_auth_user_created_create_profile
after insert on auth.users
for each row
execute function public.handle_new_user_profile();

insert into public.perfiles (id, nombre, email)
select
  user_account.id,
  coalesce(
    nullif(btrim(user_account.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(user_account.raw_user_meta_data ->> 'name'), ''),
    'User'
  ),
  nullif(btrim(user_account.email), '')
from auth.users user_account
where not exists (
  select 1
  from public.perfiles existing_profile
  where existing_profile.id = user_account.id
)
on conflict (id) do nothing;
