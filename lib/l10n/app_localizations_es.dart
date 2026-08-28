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
  String get financeTabCycles => 'Ciclos';

  @override
  String get financeCyclesTitle => 'Ciclos';

  @override
  String get financeCyclesSubtitle =>
      'Seguimiento de animales, gastos y mezclas por ciclo productivo.';

  @override
  String get financeCyclesLoadingLabel => 'Cargando ciclos';

  @override
  String get financeCyclesUnavailableTitle =>
      'Los ciclos no están disponibles para este acceso';

  @override
  String get financeCyclesUnavailableMessage =>
      'Solo propietarios y editores pueden consultar Economics V2 desde esta granja.';

  @override
  String get financeCyclesErrorTitle => 'No pudimos cargar los ciclos';

  @override
  String get financeCyclesErrorMessage =>
      'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get financeCyclesDisabledTitle => 'Economics V2 está deshabilitado';

  @override
  String get financeCyclesDisabledMessage =>
      'Activa Economics V2 para esta granja antes de consultar sus ciclos.';

  @override
  String get financeCyclesEmptyTitle => 'Aún no hay ciclos';

  @override
  String get financeCyclesEmptyMessage =>
      'Crea el primer ciclo para comenzar a registrar su actividad productiva.';

  @override
  String get financeCyclesAdd => 'Crear ciclo';

  @override
  String get financeCyclesAggregateTotalLabel => 'Ciclos totales';

  @override
  String get financeCyclesAggregateOpenLabel => 'Ciclos abiertos';

  @override
  String get financeCyclesAggregateAnimalsLabel => 'Animales activos';

  @override
  String get financeCyclesAggregateExpensesLabel => 'Gastos directos';

  @override
  String financeCyclesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ciclos',
      one: '1 ciclo',
    );
    return '$_temp0';
  }

  @override
  String financeCyclesOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abiertos',
      one: '1 abierto',
    );
    return '$_temp0';
  }

  @override
  String financeCyclesActiveAnimals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count animales con asignación activa',
      one: '1 animal con asignación activa',
    );
    return '$_temp0';
  }

  @override
  String financeCyclesDirectExpenses(String amount) {
    return 'Gastos directos: $amount';
  }

  @override
  String get financeCycleStatusOpen => 'Abierto';

  @override
  String get financeCycleStatusClosed => 'Cerrado';

  @override
  String get financeCycleStatusProductionClosed => 'Producción cerrada';

  @override
  String get financeCycleStatusSettled => 'Liquidado';

  @override
  String financeCyclePeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String financeCycleAnimals(int active, int exited) {
    return '$active con asignación activa • $exited salieron';
  }

  @override
  String financeCycleMixtures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mezclas vinculadas',
      one: '1 mezcla vinculada',
      zero: 'Sin mezclas vinculadas',
    );
    return '$_temp0';
  }

  @override
  String financeCycleLatestLinkedGroup(String name) {
    return 'Grupo de la mezcla más reciente: $name';
  }

  @override
  String get financeCycleSummaryAnimalsLabel => 'Animales';

  @override
  String get financeCycleSummaryFeedsLabel => 'Alimentos';

  @override
  String get financeCycleSummaryExpensesLabel => 'Gastos';

  @override
  String get financeCycleViewDetail => 'Ver detalle';

  @override
  String get financeCycleCreateTitle => 'Crear ciclo';

  @override
  String get financeCycleCreateSubtitle =>
      'Define el propósito y las fechas del nuevo ciclo.';

  @override
  String get financeCycleInitialOpenInfo =>
      'El ciclo se creará abierto y listo para registrar actividad.';

  @override
  String get financeCyclePurposeLabel => 'Propósito';

  @override
  String get financeCycleStartDateLabel => 'Fecha de inicio';

  @override
  String get financeCycleEndDateLabel => 'Fecha de término (opcional)';

  @override
  String get financeCycleCancel => 'Cancelar';

  @override
  String get financeCycleCreate => 'Crear ciclo';

  @override
  String get financeCycleValidation =>
      'Selecciona un propósito y una fecha de inicio válidos.';

  @override
  String get financeCycleCreateError =>
      'No pudimos crear el ciclo. Inténtalo de nuevo.';

  @override
  String financeCycleOpenSemantics(String name) {
    return 'Abrir ciclo $name';
  }

  @override
  String get financeCycleWorkspaceBack => 'Volver a ciclos';

  @override
  String get financeCycleWorkspaceOverview => 'Resumen';

  @override
  String get financeCycleWorkspaceAnimals => 'Animales';

  @override
  String get financeCycleWorkspaceFeeds => 'Alimentación';

  @override
  String get financeCycleWorkspaceExpenses => 'Gastos';

  @override
  String get financeCycleWorkspaceProjections => 'Proyecciones';

  @override
  String get financeCycleWorkspaceClose => 'Cierre';

  @override
  String get financeCycleActiveAnimalsMetric => 'Animales activos';

  @override
  String get financeCycleFeedCostMetric => 'Costo de alimentación';

  @override
  String get financeCycleDirectExpensesMetric => 'Gastos directos';

  @override
  String get financeCycleResultMetric => 'Resultado';

  @override
  String get financeCycleAnimalsNavigationSubtitle =>
      'Gestiona las asignaciones del ciclo.';

  @override
  String get financeCycleFeedsNavigationSubtitle =>
      'Revisa mezclas y costos de alimentación.';

  @override
  String get financeCycleExpensesNavigationSubtitle =>
      'Consulta los gastos directos registrados.';

  @override
  String get financeCycleProjectionsNavigationSubtitle =>
      'Explora escenarios económicos del ciclo.';

  @override
  String get financeCycleResultNavigationTitle => 'Resultado final';

  @override
  String get financeCycleResultNavigationSubtitle =>
      'Revisa el cierre y el resultado definitivo.';

  @override
  String financeCycleActiveValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activos',
      one: '1 activo',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleNavigationView => 'Ver';

  @override
  String get financeCycleCloseAction => 'Cerrar ciclo';

  @override
  String get financeCycleWorkspaceLoadError =>
      'No pudimos cargar los datos del ciclo.';

  @override
  String get financeCycleCompatibilityMessage =>
      'Este servidor solo permite consultar el resumen del ciclo. Actualiza el contrato de Economics V2 para usar animales, alimentación, gastos, proyecciones y cierre.';

  @override
  String financeCycleRevenue(String amount) {
    return 'Ingresos: $amount';
  }

  @override
  String financeCycleTotalCost(String amount) {
    return 'Costo total: $amount';
  }

  @override
  String financeCycleProfit(String amount) {
    return 'Resultado: $amount';
  }

  @override
  String financeCycleMemberSince(String date) {
    return 'Desde $date';
  }

  @override
  String get financeCycleAssignedAnimalsMetric => 'Asignados';

  @override
  String get financeCycleAvailableAnimalsMetric => 'Disponibles';

  @override
  String get financeCycleAnimalsAssignedTitle => 'Asignados al ciclo';

  @override
  String financeCycleAnimalsAssignedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count animales asignados',
      one: '1 animal asignado',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleAnimalsAssignedEmpty =>
      'Aún no hay animales asignados a este ciclo.';

  @override
  String get financeCycleAnimalsAvailableTitle => 'Disponibles para asignar';

  @override
  String financeCycleAnimalsAvailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count animales disponibles',
      one: '1 animal disponible',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleAnimalsAvailableEmpty =>
      'No hay animales disponibles para asignar.';

  @override
  String get financeCycleAssignmentActive => 'Activo';

  @override
  String get financeCycleAssignmentFinished => 'Finalizado';

  @override
  String financeCycleFeedCost(String amount) {
    return 'Costo: $amount';
  }

  @override
  String get financeCycleLinkedFeedsMetric => 'Vinculadas';

  @override
  String get financeCycleAvailableFeedsMetric => 'Disponibles';

  @override
  String get financeCycleFeedsLinkedTitle => 'Alimentación vinculada';

  @override
  String financeCycleFeedsLinkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periodos registrados',
      one: '1 periodo registrado',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleFeedsLinkedEmpty =>
      'Aún no hay alimentación vinculada a este ciclo.';

  @override
  String get financeCycleFeedsAvailableTitle => 'Mezclas disponibles';

  @override
  String financeCycleFeedsAvailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mezclas disponibles',
      one: '1 mezcla disponible',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleFeedsAvailableEmpty =>
      'No hay mezclas disponibles para vincular.';

  @override
  String financeCycleFeedPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get financeCycleFeedActive => 'Activa';

  @override
  String get financeCycleFeedFinished => 'Finalizada';

  @override
  String financeCycleExpenseItem(String category, String amount) {
    return '$category: $amount';
  }

  @override
  String get financeCycleUncategorizedExpense => 'Sin categoría';

  @override
  String get financeCycleExpensesTotalMetric => 'Total registrado';

  @override
  String get financeCycleExpensesCountMetric => 'Registros';

  @override
  String get financeCycleExpensesHistoryTitle => 'Historial de gastos';

  @override
  String financeCycleExpensesRecordedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos registrados',
      one: '1 gasto registrado',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleExpensesEmpty =>
      'Aún no hay gastos registrados en este ciclo.';

  @override
  String financeCycleExpenseDate(String date) {
    return 'Registrado el $date';
  }

  @override
  String financeCycleProjectionBalance(String amount) {
    return 'Saldo proyectado: $amount';
  }

  @override
  String get financeCycleProjectionsEmpty =>
      'Aún no hay proyecciones guardadas para este ciclo.';

  @override
  String financeCycleProjectionCreatedOn(String date) {
    return 'Proyección del $date';
  }

  @override
  String get financeCycleProjectedRevenueMetric => 'Ingresos proyectados';

  @override
  String get financeCycleProjectedCostMetric => 'Costo proyectado';

  @override
  String get financeCycleProjectedBalanceMetric => 'Saldo proyectado';

  @override
  String get financeCycleProjectionAssumptionsTitle => 'Supuestos';

  @override
  String financeCycleProjectionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleReadyToClose =>
      'La producción está lista para cerrarse.';

  @override
  String get financeCycleNotReadyToClose =>
      'Aún faltan requisitos para cerrar la producción.';

  @override
  String get financeCycleReadyToSettle =>
      'El ciclo está listo para liquidarse.';

  @override
  String get financeCycleCloseRequirementsTitle => 'Requisitos de cierre';

  @override
  String get financeCycleCloseMembersCriterion => 'Animales asignados';

  @override
  String get financeCycleCloseFeedCriterion => 'Alimentación vinculada';

  @override
  String get financeCycleCloseOutputCriterion =>
      'Producción disponible para venta';

  @override
  String get financeCycleCloseSalesCriterion =>
      'Ventas dentro de la producción registrada';

  @override
  String financeCycleCloseOpenFeedsCriterion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periodos de alimentación abiertos',
      one: '1 periodo de alimentación abierto',
      zero: 'Sin periodos de alimentación abiertos',
    );
    return '$_temp0';
  }

  @override
  String get financeCycleCriterionComplete => 'Completo';

  @override
  String get financeCycleCriterionPending => 'Pendiente';

  @override
  String get financeCycleFinalResultTitle => 'Resultado final';

  @override
  String financeCycleSettledOn(String date) {
    return 'Ciclo liquidado el $date';
  }

  @override
  String get financeCycleFinalRevenueMetric => 'Ingresos';

  @override
  String get financeCycleFinalCostMetric => 'Costo total';

  @override
  String get financeCycleFinalProfitMetric => 'Resultado';

  @override
  String get financeCycleReadinessMissingMembers =>
      'Agrega al menos un animal al ciclo.';

  @override
  String get financeCycleReadinessMissingFeed =>
      'Vincula al menos una alimentación al ciclo.';

  @override
  String get financeCycleReadinessMissingSaleableOutput =>
      'Registra producción disponible para la venta.';

  @override
  String get financeCycleReadinessSalesExceedOutput =>
      'Las ventas superan la producción registrada.';

  @override
  String get financeCycleReadinessOpenFeedIntervals =>
      'Cierra los periodos de alimentación pendientes.';

  @override
  String get financeCycleReadinessProductionNotClosed =>
      'La producción aún no se ha cerrado.';

  @override
  String financeCycleReadinessReason(String reason) {
    return '• $reason';
  }

  @override
  String financeCycleAssignAnimal(String name) {
    return 'Asignar $name';
  }

  @override
  String financeCycleLinkFeed(String name) {
    return 'Vincular $name';
  }

  @override
  String get financeCycleAddExpense => 'Registrar gasto';

  @override
  String get financeCycleExpenseCategoryLabel => 'Categoría';

  @override
  String get financeCycleExpenseAmountLabel => 'Monto';

  @override
  String get financeCycleNoteLabel => 'Nota (opcional)';

  @override
  String get financeCycleSave => 'Guardar';

  @override
  String get financeCycleInvalidForm => 'Revisa los valores ingresados.';

  @override
  String get financeCycleAddProjection => 'Nueva proyección';

  @override
  String get financeCycleProjectionUnitPriceLabel => 'Precio unitario esperado';

  @override
  String get financeCycleProjectionProductionPerDayLabel =>
      'Producción por día';

  @override
  String get financeCycleProjectionFeedPerDayLabel => 'Alimento por día';

  @override
  String get financeCycleProjectionOtherCostsLabel => 'Otros costos';

  @override
  String get financeCycleProjectionHorizonLabel => 'Horizonte en días';

  @override
  String get financeCycleCloseProductionAction => 'Cerrar producción';

  @override
  String get financeCycleFinalizeAction => 'Liquidar ciclo';

  @override
  String get financeCycleMutationError =>
      'No pudimos completar la operación. Inténtalo de nuevo.';

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
  String get breakEvenPricePerEggLabel => '\$/huevo';

  @override
  String get breakEvenCardDescription =>
      'Costo mínimo de venta para cubrir la operación';

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
  String financeCompactMetrics(String birds, String eggsRate, String feedRate) {
    return '$birds aves • $eggsRate huevo/(día·ave) • $feedRate kg/(día·ave)';
  }

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
    return '$start – $end';
  }

  @override
  String breakEvenCardSemantics(String groupName, String price, String margin) {
    return '$groupName. Precio de equilibrio por huevo: $price. $margin.';
  }

  @override
  String get economicsV2PurposePostura => 'Postura';

  @override
  String get economicsV2PurposeCarne => 'Carne';

  @override
  String get economicsV2PurposeOrnamental => 'Ornamental';

  @override
  String get economicsV2AttributableCost => 'Costo atribuible';

  @override
  String get economicsV2CanonicalRevenue => 'Ingreso canónico';

  @override
  String get economicsV2BreakEven => 'Punto de equilibrio';

  @override
  String get economicsV2BasisEggs => 'huevos';

  @override
  String get economicsV2BasisAnimalsSold => 'animales vendidos';

  @override
  String get economicsV2BasisSpecimensSold => 'especímenes vendidos';

  @override
  String get economicsV2SelectPurposePostura =>
      'Seleccionar propósito: postura';

  @override
  String get economicsV2SelectPurposeCarne => 'Seleccionar propósito: carne';

  @override
  String get economicsV2SelectPurposeOrnamental =>
      'Seleccionar propósito: ornamental';

  @override
  String get economicsV2ProductionCycles => 'Ciclos de producción';

  @override
  String get economicsV2OpenProductionCycles => 'Abrir ciclos de producción';

  @override
  String economicsV2LifecycleStep(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      'title': 'Crear ciclo V2',
      'purpose': 'Propósito',
      'create': 'Crear ciclo',
      'created': 'Ciclo creado',
      'animal': 'Animal',
      'assign': 'Asignar animal',
      'assigned': 'Animal asignado',
      'expense': 'Monto del gasto',
      'record': 'Registrar gasto',
      'recorded': 'Gasto registrado',
      'feed': 'Mezcla de alimento',
      'link': 'Vincular alimento',
      'linked': 'Alimento vinculado',
      'failure': 'No se pudo completar el paso.',
      'invalid': 'Ingresa un monto válido.',
      'other': '',
    });
    return '$_temp0';
  }
}
