-- Retire client execution of the legacy cycle expense writer family for all purposes.
-- Existing Flutter controls using these writers require a separate replacement.
-- Owner/internal execution and general cycle deletion cascades remain out of scope.

REVOKE EXECUTE ON FUNCTION public.registrar_gasto_ciclo_v2(uuid,uuid,date,numeric,text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.registrar_gasto_ciclo_v2_con_categoria(uuid,uuid,date,numeric,text,text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION economics_v2.record_cycle_expense_impl(uuid,uuid,date,numeric,text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION economics_v2.record_cycle_expense_with_category_impl(uuid,uuid,date,numeric,text,text) FROM PUBLIC, anon, authenticated;
