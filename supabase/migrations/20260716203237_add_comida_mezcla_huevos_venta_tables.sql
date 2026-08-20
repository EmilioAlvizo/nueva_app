-- ============ AJUSTE: comida ya no lleva grupo_id ni auditoria ============
alter table public.comida drop column if exists grupo_id;
alter table public.comida drop column if exists created_by;
alter table public.comida drop column if exists created_at;

-- ============ AJUSTE: mezcla ahora se asocia a un grupo ============
alter table public.mezcla
  add column grupo_id uuid not null,
  add constraint mezcla_grupo_id_fkey foreign key (grupo_id) references public.grupos (id);

-- ============ RECOLECCION_HUEVO ============
create table public.recoleccion_huevo (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  grupo_id uuid not null,
  fecha_recoleccion date not null default current_date,
  buenos integer not null default 0,
  rotos integer not null default 0,
  created_by uuid null,
  created_at timestamp with time zone not null default now(),
  constraint recoleccion_huevo_pkey primary key (id),
  constraint recoleccion_huevo_granja_id_fkey foreign key (granja_id) references public.granjas (id) on delete cascade,
  constraint recoleccion_huevo_grupo_id_fkey foreign key (grupo_id) references public.grupos (id),
  constraint recoleccion_huevo_created_by_fkey foreign key (created_by) references public.perfiles (id)
);

-- ============ VENTA_HUEVO ============
create table public.venta_huevo (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  grupo_id uuid null,
  fecha_venta date not null default current_date,
  cantidad integer not null,
  precio numeric not null,
  created_by uuid null,
  created_at timestamp with time zone not null default now(),
  constraint venta_huevo_pkey primary key (id),
  constraint venta_huevo_granja_id_fkey foreign key (granja_id) references public.granjas (id) on delete cascade,
  constraint venta_huevo_grupo_id_fkey foreign key (grupo_id) references public.grupos (id),
  constraint venta_huevo_created_by_fkey foreign key (created_by) references public.perfiles (id)
);

-- ============ VENTA_ANIMAL ============
create table public.venta_animal (
  id uuid not null default extensions.uuid_generate_v4 (),
  granja_id uuid not null,
  grupo_id uuid null,
  tipo_animal_id uuid not null,
  animal_id uuid not null,
  fecha_venta date not null default current_date,
  precio numeric null,
  peso numeric null,
  created_by uuid null,
  created_at timestamp with time zone not null default now(),
  constraint venta_animal_pkey primary key (id),
  constraint venta_animal_granja_id_fkey foreign key (granja_id) references public.granjas (id) on delete cascade,
  constraint venta_animal_grupo_id_fkey foreign key (grupo_id) references public.grupos (id),
  constraint venta_animal_tipo_animal_id_fkey foreign key (tipo_animal_id) references public.tipo_animal (id),
  constraint venta_animal_animal_id_fkey foreign key (animal_id) references public.animales (id),
  constraint venta_animal_created_by_fkey foreign key (created_by) references public.perfiles (id)
);
