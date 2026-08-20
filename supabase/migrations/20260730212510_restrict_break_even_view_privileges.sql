revoke all privileges on table public.puntos_equilibrio_huevos from authenticated;
revoke all privileges on table public.puntos_equilibrio_huevos from service_role;
grant select on table public.puntos_equilibrio_huevos to authenticated;
grant select on table public.puntos_equilibrio_huevos to service_role;