// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get financesTitle => 'Finanzas';

  @override
  String get financeTabBalance => 'Equilibrio';

  @override
  String get financeTabIncome => 'Ingresos';

  @override
  String get financeTabExpenses => 'Gastos';

  @override
  String get financeTabCharts => 'Gráficos';

  @override
  String get financeBalanceHeading => 'Punto de equilibrio por mezcla';

  @override
  String get financeBalanceSubtitle =>
      'Precio mínimo por huevo necesario para cubrir el costo de alimento de cada mezcla.';

  @override
  String get financeErrorTitle => 'No pudimos cargar los datos de equilibrio';

  @override
  String get financeErrorMessage => 'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get financeRetry => 'Reintentar';

  @override
  String get financeBalanceEmptyTitle => 'Aún no hay datos de equilibrio';

  @override
  String get financeBalanceEmptyMessage =>
      'Los resultados aparecerán cuando la granja seleccionada tenga mezclas de alimento con producción de huevos.';

  @override
  String get financeIncomeUnavailableTitle =>
      'Los ingresos aún no están disponibles';

  @override
  String get financeIncomeUnavailableMessage =>
      'Esta pestaña está lista para mostrar ingresos cuando se defina una fuente de datos verificada.';

  @override
  String get financeExpensesUnavailableTitle =>
      'Los gastos aún no están disponibles';

  @override
  String get financeExpensesUnavailableMessage =>
      'Esta pestaña está lista para mostrar gastos cuando se defina una fuente de datos verificada.';

  @override
  String get financeChartsUnavailableTitle =>
      'Los gráficos financieros aún no están disponibles';

  @override
  String get financeChartsUnavailableMessage =>
      'Los gráficos se habilitarán cuando existan datos verificados de ingresos y gastos.';

  @override
  String get financeNoFabricatedData =>
      'No se muestran estimaciones ni datos financieros inventados.';

  @override
  String get breakEvenPriceLabel => 'Precio de equilibrio';

  @override
  String get breakEvenPricePerEggLabel => 'Precio de equilibrio por huevo';

  @override
  String get breakEvenCardDescription =>
      'Precio mínimo por huevo bueno necesario para cubrir los costos de alimento.';

  @override
  String financeMarginValue(String value) {
    return 'Margen $value %';
  }

  @override
  String get financeMarginUnavailable => 'Margen no disponible';

  @override
  String get totalCostLabel => 'Costo total';

  @override
  String get goodEggsLabel => 'Huevos buenos';

  @override
  String get brokenEggsLabel => 'Huevos rotos';

  @override
  String get foodCostLabel => 'Costo de alimento';

  @override
  String get totalFeedConsumptionLabel => 'Consumo total';

  @override
  String get weightedAverageBirdsLabel => 'Aves promedio ponderado';

  @override
  String get eggsPerDayLabel => 'Huevos por día';

  @override
  String get eggsPerDayPerBirdLabel => 'Huevos por día por ave';

  @override
  String get feedPerDayLabel => 'Consumo por día';

  @override
  String get feedPerDayPerBirdLabel => 'Consumo por día por ave';

  @override
  String get averageSalePriceLabel => 'Precio promedio de venta';

  @override
  String get mixtureDurationLabel => 'Duración';

  @override
  String financeDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String financeKilograms(String value) {
    return '$value kg';
  }

  @override
  String get periodLabel => 'Periodo';

  @override
  String get ongoingLabel => 'En curso';

  @override
  String get notAvailableLabel => 'No disponible';

  @override
  String get breakEvenUnavailableReason =>
      'No se registraron huevos buenos para esta mezcla.';

  @override
  String financeDateRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String breakEvenCardSemantics(String groupName, String price, String margin) {
    return '$groupName. Precio de equilibrio por huevo: $price. $margin.';
  }
}
