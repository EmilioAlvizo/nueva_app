-- Extensions
create extension if not exists "uuid-ossp" with schema extensions;

-- Enum para roles de miembros de granja
create type public.rol_miembro as enum ('owner', 'editor', 'viewer');

-- ============ PERFILES ============
create table public.perfiles (
  id uuid not null,
  nombre text not null,
  avatar_url text null,
  created_at timestamp with time zone not null default now(),
  email text null,
  constraint perfiles_pkey primary key (id),
  constraint perfiles_id_fkey foreign key (id) references auth.users (id) on delete cascade
);

-- ============ GRANJAS ============
create table public.granjas (
  id uuid not null default gen_random_uuid (),
  owner_id uuid not null,
  nombre text not null,
  descripcion text null,
  ubicacion text null,
  created_by uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  constraint granja_pkey primary key (id),
  constraint granja_created_by_fkey foreign key (created_by) references perfiles (id),
  constraint granja_owner_id_fkey foreign key (owner_id) references perfiles (id)
);

-- ============ MIEMBROS_GRANJA ============
create table public.miembros_granja (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  user_id uuid not null,
  rol public.rol_miembro not null default 'viewer'::rol_miembro,
  joined_at timestamp with time zone not null default now(),
  invited_by uuid null,
  constraint miembros_granja_pkey primary key (id),
  constraint miembros_granja_granja_id_user_id_key unique (granja_id, user_id),
  constraint miembros_granja_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade,
  constraint miembros_granja_invited_by_fkey foreign key (invited_by) references perfiles (id),
  constraint miembros_granja_user_id_fkey foreign key (user_id) references perfiles (id) on delete cascade
);

-- ============ TIPO_ANIMAL ============
create table public.tipo_animal (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  nombre text not null,
  descripcion text null,
  created_at timestamp with time zone not null default now(),
  created_by uuid not null,
  constraint tipo_animal_pkey primary key (id),
  constraint tipo_animal_granja_id_nombre_key unique (granja_id, nombre),
  constraint tipo_animal_created_by_fkey foreign key (created_by) references perfiles (id),
  constraint tipo_animal_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade
);

-- ============ GRUPOS ============
create table public.grupos (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  tipo_animal_id uuid not null,
  nombre text not null,
  descripcion text null,
  created_at timestamp with time zone not null default now(),
  created_by uuid not null,
  constraint grupos_pkey primary key (id),
  constraint grupos_granja_id_nombre_key unique (granja_id, nombre),
  constraint grupos_created_by_fkey foreign key (created_by) references perfiles (id),
  constraint grupos_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade,
  constraint grupos_tipo_animal_id_fkey foreign key (tipo_animal_id) references tipo_animal (id) on delete cascade
);

-- ============ CATALOGOS ============
create table public.cat_proposito_animal (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid null,
  nombre text not null,
  descripcion text null,
  activo boolean not null default true,
  orden smallint not null default 0,
  created_at timestamp with time zone not null default now(),
  created_by uuid null,
  constraint cat_proposito_animal_pkey primary key (id),
  constraint cat_proposito_animal_granja_id_nombre_key unique (granja_id, nombre),
  constraint cat_proposito_animal_created_by_fkey foreign key (created_by) references perfiles (id),
  constraint cat_proposito_animal_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade
);

create index if not exists cat_proposito_animal_nombre_idx on public.cat_proposito_animal using btree (nombre);

create table public.cat_razon_baja (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid null,
  nombre text not null,
  genera_ingreso boolean not null default false,
  descripcion text null,
  activo boolean not null default true,
  orden smallint not null default 0,
  created_at timestamp with time zone not null default now(),
  created_by uuid null,
  constraint cat_razon_baja_pkey primary key (id),
  constraint cat_razon_baja_granja_id_nombre_key unique (granja_id, nombre),
  constraint cat_razon_baja_created_by_fkey foreign key (created_by) references perfiles (id),
  constraint cat_razon_baja_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade
);

create table public.cat_tipo_adquisicion (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid null,
  nombre text not null,
  descripcion text null,
  activo boolean not null default true,
  orden smallint not null default 0,
  created_at timestamp with time zone not null default now(),
  created_by uuid null,
  constraint cat_tipo_adquisicion_pkey primary key (id),
  constraint cat_tipo_adquisicion_granja_id_nombre_key unique (granja_id, nombre),
  constraint cat_tipo_adquisicion_created_by_fkey foreign key (created_by) references perfiles (id),
  constraint cat_tipo_adquisicion_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade
);

create table public.cat_alimento (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid null,
  nombre text not null,
  unidad text not null default 'kg'::text,
  activo boolean not null default true,
  orden smallint not null default 0,
  created_by uuid null,
  created_at timestamp with time zone not null default now(),
  constraint cat_alimento_pkey primary key (id),
  constraint cat_alimento_created_by_fkey foreign key (created_by) references auth.users (id),
  constraint cat_alimento_granja_id_fkey foreign key (granja_id) references granjas (id)
);

-- ============ ALTAS / BAJAS / ANIMALES ============
create table public.altas_animales (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  tipo_animal_id uuid not null,
  grupo_id uuid null,
  proposito_id uuid null,
  tipo_adquisicion_id uuid null,
  proveedor text null,
  fecha_alta date not null default current_date,
  cantidad_animales integer not null default 1,
  costo_total numeric null,
  notas text null,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint altas_animales_pkey primary key (id),
  constraint altas_animales_granja_id_fkey foreign key (granja_id) references granjas (id),
  constraint altas_animales_grupo_id_fkey foreign key (grupo_id) references grupos (id),
  constraint altas_animales_created_by_fkey foreign key (created_by) references auth.users (id),
  constraint altas_animales_proposito_id_fkey foreign key (proposito_id) references cat_proposito_animal (id),
  constraint altas_animales_tipo_adquisicion_id_fkey foreign key (tipo_adquisicion_id) references cat_tipo_adquisicion (id),
  constraint altas_animales_tipo_animal_id_fkey foreign key (tipo_animal_id) references tipo_animal (id)
);

create table public.bajas_animales (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  tipo_animal_id uuid not null,
  razon_baja_id uuid not null,
  fecha_baja date not null default current_date,
  cantidad_animales integer not null default 1,
  importe_total numeric null,
  notas text null,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint bajas_animales_pkey primary key (id),
  constraint bajas_animales_created_by_fkey foreign key (created_by) references auth.users (id),
  constraint bajas_animales_granja_id_fkey foreign key (granja_id) references granjas (id),
  constraint bajas_animales_razon_baja_id_fkey foreign key (razon_baja_id) references cat_razon_baja (id),
  constraint bajas_animales_tipo_animal_id_fkey foreign key (tipo_animal_id) references tipo_animal (id)
);

create table public.animales (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  tipo_animal_id uuid not null,
  grupo_id uuid null,
  alta_id uuid null,
  baja_id uuid null,
  brazalete smallint null,
  proposito_id uuid null,
  tipo_adquisicion_id uuid null,
  fecha_adquisicion date not null default current_date,
  costo_adquisicion numeric null,
  activo boolean not null default true,
  notas text null,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint animales_pkey primary key (id),
  constraint animales_baja_id_fkey foreign key (baja_id) references bajas_animales (id),
  constraint animales_created_by_fkey foreign key (created_by) references auth.users (id),
  constraint animales_granja_id_fkey foreign key (granja_id) references granjas (id),
  constraint animales_grupo_id_fkey foreign key (grupo_id) references grupos (id),
  constraint animales_proposito_id_fkey foreign key (proposito_id) references cat_proposito_animal (id),
  constraint animales_tipo_adquisicion_id_fkey foreign key (tipo_adquisicion_id) references cat_tipo_adquisicion (id),
  constraint animales_alta_id_fkey foreign key (alta_id) references altas_animales (id),
  constraint animales_tipo_animal_id_fkey foreign key (tipo_animal_id) references tipo_animal (id)
);

create unique index if not exists idx_bracelet_unique_per_tipo on public.animales using btree (granja_id, tipo_animal_id, brazalete)
where (brazalete is not null);

-- ============ TRIGGER: agregar owner como miembro al crear granja ============
create function public.fn_agregar_owner_como_miembro2()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.miembros_granja (granja_id, user_id, rol, invited_by)
  values (new.id, new.owner_id, 'owner', new.created_by)
  on conflict (granja_id, user_id) do nothing;
  return new;
end;
$$;

create trigger trg_nueva_granja
after insert on public.granjas
for each row
execute function public.fn_agregar_owner_como_miembro2();

-- ============ NUEVAS TABLAS DE COMIDA (prueba) ============
create table public.cat_comida (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid null,
  nombre text not null,
  activo boolean not null default true,
  created_by uuid null,
  created_at timestamp with time zone not null default now(),
  constraint cat_comida_pkey primary key (id),
  constraint cat_comida_created_by_fkey foreign key (created_by) references perfiles (id),
  constraint cat_comida_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade
);

create table public.comida (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  grupo_id uuid null,
  cat_comida_id uuid not null,
  precio numeric null,
  cantidad numeric not null,
  created_by uuid null,
  created_at timestamp with time zone not null default now(),
  constraint comida_pkey primary key (id),
  constraint comida_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade,
  constraint comida_grupo_id_fkey foreign key (grupo_id) references grupos (id),
  constraint comida_cat_comida_id_fkey foreign key (cat_comida_id) references cat_comida (id),
  constraint comida_created_by_fkey foreign key (created_by) references perfiles (id)
);

create table public.mezcla (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  fecha_inicio date not null default current_date,
  fecha_termino date null,
  created_by uuid null,
  created_at timestamp with time zone not null default now(),
  constraint mezcla_pkey primary key (id),
  constraint mezcla_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade,
  constraint mezcla_created_by_fkey foreign key (created_by) references perfiles (id)
);

create table public.mezcla_comida (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  mezcla_id uuid not null,
  comida_id uuid not null,
  cantidad numeric null,
  constraint mezcla_comida_pkey primary key (id),
  constraint mezcla_comida_granja_id_fkey foreign key (granja_id) references granjas (id) on delete cascade,
  constraint mezcla_comida_mezcla_id_fkey foreign key (mezcla_id) references mezcla (id) on delete cascade,
  constraint mezcla_comida_comida_id_fkey foreign key (comida_id) references comida (id) on delete cascade,
  constraint mezcla_comida_unique unique (mezcla_id, comida_id)
);
