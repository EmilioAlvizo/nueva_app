-- Migration: remove Huevos period dependency from operational tables.
--
-- Rollback guidance:
-- 1. Re-add nullable `periodo_alimento_id uuid` columns to
--    `public.registros_produccion` and `public.salidas_produccion`.
-- 2. Restore historical links from `public.huevos_periodo_historico` by matching
--    (`source_table`, `source_id`) back to each operational table.
-- 3. Recreate the foreign keys to `public.periodos_alimento(id)` only after the
--    backfill completes. Keep the restored columns nullable because new rows
--    created after this migration legitimately do not belong to a period.

begin;

set local lock_timeout = '5s';

create table if not exists public.huevos_periodo_historico (
  source_table text not null,
  source_id uuid not null,
  periodo_alimento_id uuid not null,
  captured_at timestamptz not null default now(),
  primary key (source_table, source_id)
);

insert into public.huevos_periodo_historico (
  source_table,
  source_id,
  periodo_alimento_id
)
select
  'registros_produccion',
  rp.id,
  rp.periodo_alimento_id
from public.registros_produccion rp
where rp.periodo_alimento_id is not null
on conflict (source_table, source_id) do update
set
  periodo_alimento_id = excluded.periodo_alimento_id,
  captured_at = now();

insert into public.huevos_periodo_historico (
  source_table,
  source_id,
  periodo_alimento_id
)
select
  'salidas_produccion',
  sp.id,
  sp.periodo_alimento_id
from public.salidas_produccion sp
where sp.periodo_alimento_id is not null
on conflict (source_table, source_id) do update
set
  periodo_alimento_id = excluded.periodo_alimento_id,
  captured_at = now();

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join unnest(c.conkey) with ordinality as cols(attnum, ordinality)
      on true
    join pg_attribute a
      on a.attrelid = t.oid
     and a.attnum = cols.attnum
    where n.nspname = 'public'
      and t.relname = 'registros_produccion'
      and a.attname = 'periodo_alimento_id'
  loop
    execute format(
      'alter table public.registros_produccion drop constraint if exists %I',
      constraint_name
    );
  end loop;

  for constraint_name in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join unnest(c.conkey) with ordinality as cols(attnum, ordinality)
      on true
    join pg_attribute a
      on a.attrelid = t.oid
     and a.attnum = cols.attnum
    where n.nspname = 'public'
      and t.relname = 'salidas_produccion'
      and a.attname = 'periodo_alimento_id'
  loop
    execute format(
      'alter table public.salidas_produccion drop constraint if exists %I',
      constraint_name
    );
  end loop;
end $$;

alter table public.registros_produccion
  drop column if exists periodo_alimento_id;

alter table public.salidas_produccion
  drop column if exists periodo_alimento_id;

commit;
