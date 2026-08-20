create table public.app_releases (
  id bigint generated always as identity primary key,
  platform text not null default 'android',
  channel text not null default 'stable',
  version_code integer not null,
  version_name text not null,
  bucket_id text not null default 'android-releases',
  object_path text not null,
  sha256 text not null,
  size_bytes bigint not null,
  release_notes text not null default '',
  mandatory boolean not null default false,
  minimum_supported_version_code integer,
  is_active boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  constraint app_releases_platform_android check (platform = 'android'),
  constraint app_releases_channel_stable check (channel = 'stable'),
  constraint app_releases_version_code_positive check (version_code > 0),
  constraint app_releases_version_name_present check (length(trim(version_name)) > 0),
  constraint app_releases_bucket_android check (bucket_id = 'android-releases'),
  constraint app_releases_object_path_safe check (
    length(trim(object_path)) > 0
    and object_path !~ '^/'
    and object_path !~ '(^|/)\.\.?(/|$)'
    and object_path ~ '\.apk$'
  ),
  constraint app_releases_sha256_format check (sha256 ~ '^[0-9a-f]{64}$'),
  constraint app_releases_size_bytes_positive check (size_bytes > 0),
  constraint app_releases_minimum_version_positive check (
    minimum_supported_version_code is null
    or (
      minimum_supported_version_code > 0
      and minimum_supported_version_code <= version_code
    )
  ),
  constraint app_releases_active_is_published check (
    not is_active or published_at is not null
  ),
  constraint app_releases_platform_channel_version_unique
    unique (platform, channel, version_code)
);

alter table public.app_releases enable row level security;

revoke all on table public.app_releases from anon, authenticated;
revoke all on sequence public.app_releases_id_seq from anon, authenticated;
grant select, insert, update, delete on table public.app_releases to service_role;
grant usage, select on sequence public.app_releases_id_seq to service_role;

create index app_releases_active_lookup_idx
  on public.app_releases (platform, channel, version_code desc, published_at desc)
  where is_active;

insert into storage.buckets (id, name, public, allowed_mime_types)
values (
  'android-releases',
  'android-releases',
  false,
  array['application/vnd.android.package-archive']
)
on conflict (id) do update
set public = false,
    allowed_mime_types = excluded.allowed_mime_types;