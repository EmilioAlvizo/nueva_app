import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// Título de la sección de finanzas
  ///
  /// In es, this message translates to:
  /// **'Finanzas'**
  String get financesTitle;

  /// No description provided for @financeTabBalance.
  ///
  /// In es, this message translates to:
  /// **'Equilibrio'**
  String get financeTabBalance;

  /// No description provided for @financeTabIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get financeTabIncome;

  /// No description provided for @financeTabExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get financeTabExpenses;

  /// No description provided for @financeTabCharts.
  ///
  /// In es, this message translates to:
  /// **'Gráficos'**
  String get financeTabCharts;

  /// Etiqueta de la pestaña de ciclos en finanzas
  ///
  /// In es, this message translates to:
  /// **'Ciclos'**
  String get financeTabCycles;

  /// Título del panel de ciclos productivos
  ///
  /// In es, this message translates to:
  /// **'Ciclos'**
  String get financeCyclesTitle;

  /// Descripción del panel de ciclos productivos
  ///
  /// In es, this message translates to:
  /// **'Seguimiento de animales, gastos y mezclas por ciclo productivo.'**
  String get financeCyclesSubtitle;

  /// Etiqueta accesible del indicador de carga de ciclos
  ///
  /// In es, this message translates to:
  /// **'Cargando ciclos'**
  String get financeCyclesLoadingLabel;

  /// Título mostrado cuando el acceso local no permite consultar ciclos
  ///
  /// In es, this message translates to:
  /// **'Los ciclos no están disponibles para este acceso'**
  String get financeCyclesUnavailableTitle;

  /// Explicación mostrada cuando el acceso local no permite consultar ciclos
  ///
  /// In es, this message translates to:
  /// **'Solo propietarios y editores pueden consultar Economics V2 desde esta granja.'**
  String get financeCyclesUnavailableMessage;

  /// Título del estado de error al cargar ciclos
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los ciclos'**
  String get financeCyclesErrorTitle;

  /// Mensaje del estado de error al cargar ciclos
  ///
  /// In es, this message translates to:
  /// **'Revisa tu conexión e inténtalo de nuevo.'**
  String get financeCyclesErrorMessage;

  /// Título mostrado cuando Economics V2 está deshabilitado para la granja
  ///
  /// In es, this message translates to:
  /// **'Economics V2 está deshabilitado'**
  String get financeCyclesDisabledTitle;

  /// Explicación mostrada cuando Economics V2 está deshabilitado para la granja
  ///
  /// In es, this message translates to:
  /// **'Activa Economics V2 para esta granja antes de consultar sus ciclos.'**
  String get financeCyclesDisabledMessage;

  /// Título del estado sin ciclos productivos
  ///
  /// In es, this message translates to:
  /// **'Aún no hay ciclos'**
  String get financeCyclesEmptyTitle;

  /// Explicación del estado sin ciclos productivos
  ///
  /// In es, this message translates to:
  /// **'Crea el primer ciclo para comenzar a registrar su actividad productiva.'**
  String get financeCyclesEmptyMessage;

  /// Acción para abrir el formulario de creación de ciclos
  ///
  /// In es, this message translates to:
  /// **'Crear ciclo'**
  String get financeCyclesAdd;

  /// Etiqueta del total de ciclos en el resumen
  ///
  /// In es, this message translates to:
  /// **'Ciclos totales'**
  String get financeCyclesAggregateTotalLabel;

  /// Etiqueta del total de ciclos abiertos en el resumen
  ///
  /// In es, this message translates to:
  /// **'Ciclos abiertos'**
  String get financeCyclesAggregateOpenLabel;

  /// Etiqueta del total de animales activos en el resumen
  ///
  /// In es, this message translates to:
  /// **'Animales activos'**
  String get financeCyclesAggregateAnimalsLabel;

  /// Etiqueta del total de gastos directos en el resumen
  ///
  /// In es, this message translates to:
  /// **'Gastos directos'**
  String get financeCyclesAggregateExpensesLabel;

  /// Cantidad total de ciclos
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ciclo} other{{count} ciclos}}'**
  String financeCyclesCount(int count);

  /// Cantidad de ciclos abiertos
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 abierto} other{{count} abiertos}}'**
  String financeCyclesOpenCount(int count);

  /// Cantidad de animales con una asignación activa a un ciclo
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 animal con asignación activa} other{{count} animales con asignación activa}}'**
  String financeCyclesActiveAnimals(int count);

  /// Total de gastos directos del ciclo
  ///
  /// In es, this message translates to:
  /// **'Gastos directos: {amount}'**
  String financeCyclesDirectExpenses(String amount);

  /// Estado de un ciclo abierto
  ///
  /// In es, this message translates to:
  /// **'Abierto'**
  String get financeCycleStatusOpen;

  /// Estado de un ciclo cerrado
  ///
  /// In es, this message translates to:
  /// **'Cerrado'**
  String get financeCycleStatusClosed;

  /// Estado de un ciclo cuya producción está cerrada
  ///
  /// In es, this message translates to:
  /// **'Producción cerrada'**
  String get financeCycleStatusProductionClosed;

  /// Estado de un ciclo liquidado
  ///
  /// In es, this message translates to:
  /// **'Liquidado'**
  String get financeCycleStatusSettled;

  /// Periodo de fechas de un ciclo
  ///
  /// In es, this message translates to:
  /// **'{start} – {end}'**
  String financeCyclePeriod(String start, String end);

  /// Cantidades de animales con asignación activa y finalizada
  ///
  /// In es, this message translates to:
  /// **'{active} con asignación activa • {exited} salieron'**
  String financeCycleAnimals(int active, int exited);

  /// Cantidad de mezclas vinculadas al ciclo
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin mezclas vinculadas} =1{1 mezcla vinculada} other{{count} mezclas vinculadas}}'**
  String financeCycleMixtures(int count);

  /// Nombre del grupo asociado a la mezcla más reciente vinculada al ciclo
  ///
  /// In es, this message translates to:
  /// **'Grupo de la mezcla más reciente: {name}'**
  String financeCycleLatestLinkedGroup(String name);

  /// Etiqueta de animales en una tarjeta de ciclo
  ///
  /// In es, this message translates to:
  /// **'Animales'**
  String get financeCycleSummaryAnimalsLabel;

  /// Etiqueta de alimentos en una tarjeta de ciclo
  ///
  /// In es, this message translates to:
  /// **'Alimentos'**
  String get financeCycleSummaryFeedsLabel;

  /// Etiqueta de gastos en una tarjeta de ciclo
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get financeCycleSummaryExpensesLabel;

  /// Acción para abrir el detalle de un ciclo
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get financeCycleViewDetail;

  /// Título del formulario de creación de ciclos
  ///
  /// In es, this message translates to:
  /// **'Crear ciclo'**
  String get financeCycleCreateTitle;

  /// Descripción del formulario de creación de ciclos
  ///
  /// In es, this message translates to:
  /// **'Define el propósito y las fechas del nuevo ciclo.'**
  String get financeCycleCreateSubtitle;

  /// Aviso sobre el estado inicial de un ciclo nuevo
  ///
  /// In es, this message translates to:
  /// **'El ciclo se creará abierto y listo para registrar actividad.'**
  String get financeCycleInitialOpenInfo;

  /// Etiqueta del selector de propósito del ciclo
  ///
  /// In es, this message translates to:
  /// **'Propósito'**
  String get financeCyclePurposeLabel;

  /// Etiqueta del selector de fecha inicial del ciclo
  ///
  /// In es, this message translates to:
  /// **'Fecha de inicio'**
  String get financeCycleStartDateLabel;

  /// Etiqueta del selector opcional de fecha final del ciclo
  ///
  /// In es, this message translates to:
  /// **'Fecha de término (opcional)'**
  String get financeCycleEndDateLabel;

  /// Acción para cancelar la creación de un ciclo
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get financeCycleCancel;

  /// Acción para confirmar la creación de un ciclo
  ///
  /// In es, this message translates to:
  /// **'Crear ciclo'**
  String get financeCycleCreate;

  /// Mensaje de validación del formulario de ciclos
  ///
  /// In es, this message translates to:
  /// **'Selecciona un propósito y una fecha de inicio válidos.'**
  String get financeCycleValidation;

  /// Mensaje mostrado cuando falla la creación de un ciclo
  ///
  /// In es, this message translates to:
  /// **'No pudimos crear el ciclo. Inténtalo de nuevo.'**
  String get financeCycleCreateError;

  /// Etiqueta accesible para abrir el espacio de trabajo de un ciclo
  ///
  /// In es, this message translates to:
  /// **'Abrir ciclo {name}'**
  String financeCycleOpenSemantics(String name);

  /// Acción para volver a la lista de ciclos
  ///
  /// In es, this message translates to:
  /// **'Volver a ciclos'**
  String get financeCycleWorkspaceBack;

  /// Etiqueta del selector para volver a todos los ciclos
  ///
  /// In es, this message translates to:
  /// **'Todos los ciclos'**
  String get financeCycleWorkspaceAllCycles;

  /// Etiqueta contextual del detalle del ciclo
  ///
  /// In es, this message translates to:
  /// **'Detalle del ciclo'**
  String get financeCycleWorkspaceDetail;

  /// Título del detalle formado por el propósito y el grupo vinculados
  ///
  /// In es, this message translates to:
  /// **'{purpose} · {group}'**
  String financeCycleWorkspaceTitle(String purpose, String group);

  /// Periodo contextual del espacio de trabajo del ciclo
  ///
  /// In es, this message translates to:
  /// **'{start} → {end}'**
  String financeCycleWorkspacePeriod(String start, String end);

  /// Extremo actual de un ciclo que continúa abierto
  ///
  /// In es, this message translates to:
  /// **'actual'**
  String get financeCycleWorkspaceOngoing;

  /// Vista de resumen del ciclo
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get financeCycleWorkspaceOverview;

  /// Vista de animales del ciclo
  ///
  /// In es, this message translates to:
  /// **'Animales'**
  String get financeCycleWorkspaceAnimals;

  /// Vista de alimentación del ciclo
  ///
  /// In es, this message translates to:
  /// **'Alimentación'**
  String get financeCycleWorkspaceFeeds;

  /// Vista de gastos del ciclo
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get financeCycleWorkspaceExpenses;

  /// Vista de proyecciones del ciclo
  ///
  /// In es, this message translates to:
  /// **'Proyecciones'**
  String get financeCycleWorkspaceProjections;

  /// Vista de cierre y liquidación del ciclo
  ///
  /// In es, this message translates to:
  /// **'Cierre'**
  String get financeCycleWorkspaceClose;

  /// Métrica de animales activos en el detalle del ciclo
  ///
  /// In es, this message translates to:
  /// **'Animales activos'**
  String get financeCycleActiveAnimalsMetric;

  /// Métrica del costo de alimentación en el detalle del ciclo
  ///
  /// In es, this message translates to:
  /// **'Costo de alimentación'**
  String get financeCycleFeedCostMetric;

  /// Métrica de gastos directos en el detalle del ciclo
  ///
  /// In es, this message translates to:
  /// **'Gastos directos'**
  String get financeCycleDirectExpensesMetric;

  /// Métrica del resultado económico en el detalle del ciclo
  ///
  /// In es, this message translates to:
  /// **'Resultado'**
  String get financeCycleResultMetric;

  /// Métrica compacta de animales del resumen del ciclo
  ///
  /// In es, this message translates to:
  /// **'Animales'**
  String get financeCycleOverviewAnimalsMetric;

  /// Métrica compacta de gastos del resumen del ciclo
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get financeCycleOverviewExpensesMetric;

  /// Métrica compacta de alimentación del resumen del ciclo
  ///
  /// In es, this message translates to:
  /// **'Mezcla'**
  String get financeCycleOverviewFeedMetric;

  /// Métrica compacta del resultado proyectado del ciclo
  ///
  /// In es, this message translates to:
  /// **'Proyección'**
  String get financeCycleOverviewProjectionMetric;

  /// Fecha de la última actualización del resumen del ciclo
  ///
  /// In es, this message translates to:
  /// **'Última actualización: {date}'**
  String financeCycleOverviewLastUpdated(String date);

  /// Descripción de la navegación a animales del ciclo
  ///
  /// In es, this message translates to:
  /// **'Gestiona las asignaciones del ciclo.'**
  String get financeCycleAnimalsNavigationSubtitle;

  /// Descripción de la navegación a alimentación del ciclo
  ///
  /// In es, this message translates to:
  /// **'Revisa mezclas y costos de alimentación.'**
  String get financeCycleFeedsNavigationSubtitle;

  /// Descripción de la navegación a gastos del ciclo
  ///
  /// In es, this message translates to:
  /// **'Consulta los gastos directos registrados.'**
  String get financeCycleExpensesNavigationSubtitle;

  /// Título de la navegación a los gastos del ciclo
  ///
  /// In es, this message translates to:
  /// **'Gastos del ciclo'**
  String get financeCycleExpensesNavigationTitle;

  /// Título de la navegación a la proyección del ciclo
  ///
  /// In es, this message translates to:
  /// **'Proyección'**
  String get financeCycleProjectionNavigationTitle;

  /// Descripción de la navegación a proyecciones del ciclo
  ///
  /// In es, this message translates to:
  /// **'Explora escenarios económicos del ciclo.'**
  String get financeCycleProjectionsNavigationSubtitle;

  /// Título de la navegación al resultado final del ciclo
  ///
  /// In es, this message translates to:
  /// **'Resultado final'**
  String get financeCycleResultNavigationTitle;

  /// Descripción de la navegación al resultado final del ciclo
  ///
  /// In es, this message translates to:
  /// **'Revisa el cierre y el resultado definitivo.'**
  String get financeCycleResultNavigationSubtitle;

  /// Cantidad compacta de animales activos
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 activo} other{{count} activos}}'**
  String financeCycleActiveValue(int count);

  /// Valor compacto para abrir una sección del ciclo
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get financeCycleNavigationView;

  /// Acción para abrir el flujo de cierre del ciclo
  ///
  /// In es, this message translates to:
  /// **'Cerrar ciclo'**
  String get financeCycleCloseAction;

  /// Mensaje mostrado cuando falla una lectura del espacio de trabajo
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los datos del ciclo.'**
  String get financeCycleWorkspaceLoadError;

  /// Aviso mostrado cuando el servidor solo admite el contrato resumido de ciclos
  ///
  /// In es, this message translates to:
  /// **'Este servidor solo permite consultar el resumen del ciclo. Actualiza el contrato de Economics V2 para usar animales, alimentación, gastos, proyecciones y cierre.'**
  String get financeCycleCompatibilityMessage;

  /// Ingresos acumulados del ciclo
  ///
  /// In es, this message translates to:
  /// **'Ingresos: {amount}'**
  String financeCycleRevenue(String amount);

  /// Costo total acumulado del ciclo
  ///
  /// In es, this message translates to:
  /// **'Costo total: {amount}'**
  String financeCycleTotalCost(String amount);

  /// Resultado económico acumulado del ciclo
  ///
  /// In es, this message translates to:
  /// **'Resultado: {amount}'**
  String financeCycleProfit(String amount);

  /// Fecha de inicio de una asignación
  ///
  /// In es, this message translates to:
  /// **'Desde {date}'**
  String financeCycleMemberSince(String date);

  /// Métrica de animales asignados activamente al ciclo
  ///
  /// In es, this message translates to:
  /// **'Asignados'**
  String get financeCycleAssignedAnimalsMetric;

  /// Métrica de animales disponibles para asignar
  ///
  /// In es, this message translates to:
  /// **'Disponibles'**
  String get financeCycleAvailableAnimalsMetric;

  /// Título de las asignaciones de animales del ciclo
  ///
  /// In es, this message translates to:
  /// **'Asignados al ciclo'**
  String get financeCycleAnimalsAssignedTitle;

  /// Cantidad de animales asignados al ciclo
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 animal asignado} other{{count} animales asignados}}'**
  String financeCycleAnimalsAssignedCount(int count);

  /// Estado vacío de animales asignados
  ///
  /// In es, this message translates to:
  /// **'Aún no hay animales asignados a este ciclo.'**
  String get financeCycleAnimalsAssignedEmpty;

  /// Título de los animales candidatos del ciclo
  ///
  /// In es, this message translates to:
  /// **'Disponibles para asignar'**
  String get financeCycleAnimalsAvailableTitle;

  /// Cantidad de animales disponibles para asignar
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 animal disponible} other{{count} animales disponibles}}'**
  String financeCycleAnimalsAvailableCount(int count);

  /// Estado vacío de animales candidatos
  ///
  /// In es, this message translates to:
  /// **'No hay animales disponibles para asignar.'**
  String get financeCycleAnimalsAvailableEmpty;

  /// Estado de una asignación activa de animal
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get financeCycleAssignmentActive;

  /// Estado de una asignación finalizada de animal
  ///
  /// In es, this message translates to:
  /// **'Finalizado'**
  String get financeCycleAssignmentFinished;

  /// Costo de un intervalo de alimentación
  ///
  /// In es, this message translates to:
  /// **'Costo: {amount}'**
  String financeCycleFeedCost(String amount);

  /// Métrica de alimentaciones vinculadas y activas
  ///
  /// In es, this message translates to:
  /// **'Vinculadas'**
  String get financeCycleLinkedFeedsMetric;

  /// Métrica de mezclas disponibles para vincular
  ///
  /// In es, this message translates to:
  /// **'Disponibles'**
  String get financeCycleAvailableFeedsMetric;

  /// Título de los periodos de alimentación vinculados
  ///
  /// In es, this message translates to:
  /// **'Alimentación vinculada'**
  String get financeCycleFeedsLinkedTitle;

  /// Cantidad de periodos de alimentación vinculados
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 periodo registrado} other{{count} periodos registrados}}'**
  String financeCycleFeedsLinkedCount(int count);

  /// Estado vacío de alimentación vinculada
  ///
  /// In es, this message translates to:
  /// **'Aún no hay alimentación vinculada a este ciclo.'**
  String get financeCycleFeedsLinkedEmpty;

  /// Título de las mezclas candidatas para vincular
  ///
  /// In es, this message translates to:
  /// **'Mezclas disponibles'**
  String get financeCycleFeedsAvailableTitle;

  /// Cantidad de mezclas disponibles para vincular
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 mezcla disponible} other{{count} mezclas disponibles}}'**
  String financeCycleFeedsAvailableCount(int count);

  /// Estado vacío de mezclas candidatas
  ///
  /// In es, this message translates to:
  /// **'No hay mezclas disponibles para vincular.'**
  String get financeCycleFeedsAvailableEmpty;

  /// Periodo de una alimentación vinculada
  ///
  /// In es, this message translates to:
  /// **'{start} – {end}'**
  String financeCycleFeedPeriod(String start, String end);

  /// Estado de una alimentación activa
  ///
  /// In es, this message translates to:
  /// **'Activa'**
  String get financeCycleFeedActive;

  /// Estado de una alimentación finalizada
  ///
  /// In es, this message translates to:
  /// **'Finalizada'**
  String get financeCycleFeedFinished;

  /// Resumen de un gasto del ciclo
  ///
  /// In es, this message translates to:
  /// **'{category}: {amount}'**
  String financeCycleExpenseItem(String category, String amount);

  /// Categoría sustituta para gastos históricos
  ///
  /// In es, this message translates to:
  /// **'Sin categoría'**
  String get financeCycleUncategorizedExpense;

  /// Métrica del monto total de gastos registrados
  ///
  /// In es, this message translates to:
  /// **'Total registrado'**
  String get financeCycleExpensesTotalMetric;

  /// Métrica de cantidad de gastos registrados
  ///
  /// In es, this message translates to:
  /// **'Registros'**
  String get financeCycleExpensesCountMetric;

  /// Título de la lista de gastos del ciclo
  ///
  /// In es, this message translates to:
  /// **'Historial de gastos'**
  String get financeCycleExpensesHistoryTitle;

  /// Cantidad de gastos registrados
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 gasto registrado} other{{count} gastos registrados}}'**
  String financeCycleExpensesRecordedCount(int count);

  /// Estado vacío del historial de gastos
  ///
  /// In es, this message translates to:
  /// **'Aún no hay gastos registrados en este ciclo.'**
  String get financeCycleExpensesEmpty;

  /// Fecha de registro de un gasto
  ///
  /// In es, this message translates to:
  /// **'Registrado el {date}'**
  String financeCycleExpenseDate(String date);

  /// Saldo de una proyección guardada
  ///
  /// In es, this message translates to:
  /// **'Saldo proyectado: {amount}'**
  String financeCycleProjectionBalance(String amount);

  /// Estado vacío de proyecciones guardadas
  ///
  /// In es, this message translates to:
  /// **'Aún no hay proyecciones guardadas para este ciclo.'**
  String get financeCycleProjectionsEmpty;

  /// Fecha de creación de una proyección
  ///
  /// In es, this message translates to:
  /// **'Proyección del {date}'**
  String financeCycleProjectionCreatedOn(String date);

  /// Métrica de ingresos de una proyección
  ///
  /// In es, this message translates to:
  /// **'Ingresos proyectados'**
  String get financeCycleProjectedRevenueMetric;

  /// Métrica de costo total de una proyección
  ///
  /// In es, this message translates to:
  /// **'Costo proyectado'**
  String get financeCycleProjectedCostMetric;

  /// Métrica de saldo de una proyección
  ///
  /// In es, this message translates to:
  /// **'Saldo proyectado'**
  String get financeCycleProjectedBalanceMetric;

  /// Título de los supuestos usados en una proyección
  ///
  /// In es, this message translates to:
  /// **'Supuestos'**
  String get financeCycleProjectionAssumptionsTitle;

  /// Horizonte en días de una proyección
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String financeCycleProjectionDays(int count);

  /// Estado favorable para cerrar la producción
  ///
  /// In es, this message translates to:
  /// **'La producción está lista para cerrarse.'**
  String get financeCycleReadyToClose;

  /// Estado cuando el ciclo no puede cerrar producción
  ///
  /// In es, this message translates to:
  /// **'Aún faltan requisitos para cerrar la producción.'**
  String get financeCycleNotReadyToClose;

  /// Estado favorable para liquidar el ciclo
  ///
  /// In es, this message translates to:
  /// **'El ciclo está listo para liquidarse.'**
  String get financeCycleReadyToSettle;

  /// Título de los requisitos de cierre del ciclo
  ///
  /// In es, this message translates to:
  /// **'Requisitos de cierre'**
  String get financeCycleCloseRequirementsTitle;

  /// Criterio de cierre sobre animales asignados
  ///
  /// In es, this message translates to:
  /// **'Animales asignados'**
  String get financeCycleCloseMembersCriterion;

  /// Criterio de cierre sobre alimentación vinculada
  ///
  /// In es, this message translates to:
  /// **'Alimentación vinculada'**
  String get financeCycleCloseFeedCriterion;

  /// Criterio de cierre sobre producción vendible
  ///
  /// In es, this message translates to:
  /// **'Producción disponible para venta'**
  String get financeCycleCloseOutputCriterion;

  /// Criterio de cierre sobre consistencia entre ventas y producción
  ///
  /// In es, this message translates to:
  /// **'Ventas dentro de la producción registrada'**
  String get financeCycleCloseSalesCriterion;

  /// Criterio de cierre sobre periodos de alimentación abiertos
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin periodos de alimentación abiertos} =1{1 periodo de alimentación abierto} other{{count} periodos de alimentación abiertos}}'**
  String financeCycleCloseOpenFeedsCriterion(int count);

  /// Estado completo de un criterio de cierre
  ///
  /// In es, this message translates to:
  /// **'Completo'**
  String get financeCycleCriterionComplete;

  /// Estado pendiente de un criterio de cierre
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get financeCycleCriterionPending;

  /// Título del resultado definitivo de un ciclo liquidado
  ///
  /// In es, this message translates to:
  /// **'Resultado final'**
  String get financeCycleFinalResultTitle;

  /// Fecha de liquidación definitiva del ciclo
  ///
  /// In es, this message translates to:
  /// **'Ciclo liquidado el {date}'**
  String financeCycleSettledOn(String date);

  /// Métrica de ingresos del resultado final
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get financeCycleFinalRevenueMetric;

  /// Métrica de costo del resultado final
  ///
  /// In es, this message translates to:
  /// **'Costo total'**
  String get financeCycleFinalCostMetric;

  /// Métrica de ganancia o pérdida del resultado final
  ///
  /// In es, this message translates to:
  /// **'Resultado'**
  String get financeCycleFinalProfitMetric;

  /// Requisito de cierre cuando el ciclo no tiene animales
  ///
  /// In es, this message translates to:
  /// **'Agrega al menos un animal al ciclo.'**
  String get financeCycleReadinessMissingMembers;

  /// Requisito de cierre cuando el ciclo no tiene alimentación
  ///
  /// In es, this message translates to:
  /// **'Vincula al menos una alimentación al ciclo.'**
  String get financeCycleReadinessMissingFeed;

  /// Requisito de liquidación cuando falta producción vendible
  ///
  /// In es, this message translates to:
  /// **'Registra producción disponible para la venta.'**
  String get financeCycleReadinessMissingSaleableOutput;

  /// Requisito de liquidación cuando las ventas superan la producción
  ///
  /// In es, this message translates to:
  /// **'Las ventas superan la producción registrada.'**
  String get financeCycleReadinessSalesExceedOutput;

  /// Requisito de liquidación cuando existen periodos de alimentación abiertos
  ///
  /// In es, this message translates to:
  /// **'Cierra los periodos de alimentación pendientes.'**
  String get financeCycleReadinessOpenFeedIntervals;

  /// Requisito de liquidación cuando la producción permanece abierta
  ///
  /// In es, this message translates to:
  /// **'La producción aún no se ha cerrado.'**
  String get financeCycleReadinessProductionNotClosed;

  /// Motivo pendiente para el cierre de un ciclo
  ///
  /// In es, this message translates to:
  /// **'• {reason}'**
  String financeCycleReadinessReason(String reason);

  /// Acción para asignar un animal candidato
  ///
  /// In es, this message translates to:
  /// **'Asignar {name}'**
  String financeCycleAssignAnimal(String name);

  /// Acción para vincular una mezcla candidata
  ///
  /// In es, this message translates to:
  /// **'Vincular {name}'**
  String financeCycleLinkFeed(String name);

  /// Acción para abrir el formulario de gasto
  ///
  /// In es, this message translates to:
  /// **'Registrar gasto'**
  String get financeCycleAddExpense;

  /// Etiqueta de categoría del gasto
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get financeCycleExpenseCategoryLabel;

  /// Etiqueta de monto del gasto
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get financeCycleExpenseAmountLabel;

  /// Etiqueta de nota opcional
  ///
  /// In es, this message translates to:
  /// **'Nota (opcional)'**
  String get financeCycleNoteLabel;

  /// Acción para guardar datos del ciclo
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get financeCycleSave;

  /// Mensaje de validación de formularios del ciclo
  ///
  /// In es, this message translates to:
  /// **'Revisa los valores ingresados.'**
  String get financeCycleInvalidForm;

  /// Acción para abrir el formulario de proyección
  ///
  /// In es, this message translates to:
  /// **'Nueva proyección'**
  String get financeCycleAddProjection;

  /// Precio esperado por unidad en una proyección
  ///
  /// In es, this message translates to:
  /// **'Precio unitario esperado'**
  String get financeCycleProjectionUnitPriceLabel;

  /// Producción diaria esperada
  ///
  /// In es, this message translates to:
  /// **'Producción por día'**
  String get financeCycleProjectionProductionPerDayLabel;

  /// Costo diario de alimento esperado
  ///
  /// In es, this message translates to:
  /// **'Alimento por día'**
  String get financeCycleProjectionFeedPerDayLabel;

  /// Otros costos de una proyección
  ///
  /// In es, this message translates to:
  /// **'Otros costos'**
  String get financeCycleProjectionOtherCostsLabel;

  /// Cantidad de días de una proyección
  ///
  /// In es, this message translates to:
  /// **'Horizonte en días'**
  String get financeCycleProjectionHorizonLabel;

  /// Acción para cerrar la etapa productiva
  ///
  /// In es, this message translates to:
  /// **'Cerrar producción'**
  String get financeCycleCloseProductionAction;

  /// Acción para liquidar definitivamente el ciclo
  ///
  /// In es, this message translates to:
  /// **'Liquidar ciclo'**
  String get financeCycleFinalizeAction;

  /// Mensaje mostrado cuando falla una mutación del ciclo
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la operación. Inténtalo de nuevo.'**
  String get financeCycleMutationError;

  /// No description provided for @financeBalanceHeading.
  ///
  /// In es, this message translates to:
  /// **'Punto de equilibrio por mezcla'**
  String get financeBalanceHeading;

  /// No description provided for @financeBalanceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Precio mínimo por huevo necesario para cubrir el costo de alimento de cada mezcla.'**
  String get financeBalanceSubtitle;

  /// No description provided for @financeErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los datos de equilibrio'**
  String get financeErrorTitle;

  /// No description provided for @financeErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu conexión e inténtalo de nuevo.'**
  String get financeErrorMessage;

  /// No description provided for @financeRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get financeRetry;

  /// No description provided for @financeBalanceEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay datos de equilibrio'**
  String get financeBalanceEmptyTitle;

  /// No description provided for @financeBalanceEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Los resultados aparecerán cuando la granja seleccionada tenga mezclas de alimento con producción de huevos.'**
  String get financeBalanceEmptyMessage;

  /// No description provided for @financeIncomeUnavailableTitle.
  ///
  /// In es, this message translates to:
  /// **'Los ingresos aún no están disponibles'**
  String get financeIncomeUnavailableTitle;

  /// No description provided for @financeIncomeUnavailableMessage.
  ///
  /// In es, this message translates to:
  /// **'Esta pestaña está lista para mostrar ingresos cuando se defina una fuente de datos verificada.'**
  String get financeIncomeUnavailableMessage;

  /// No description provided for @financeExpensesUnavailableTitle.
  ///
  /// In es, this message translates to:
  /// **'Los gastos aún no están disponibles'**
  String get financeExpensesUnavailableTitle;

  /// No description provided for @financeExpensesUnavailableMessage.
  ///
  /// In es, this message translates to:
  /// **'Esta pestaña está lista para mostrar gastos cuando se defina una fuente de datos verificada.'**
  String get financeExpensesUnavailableMessage;

  /// No description provided for @financeChartsUnavailableTitle.
  ///
  /// In es, this message translates to:
  /// **'Los gráficos financieros aún no están disponibles'**
  String get financeChartsUnavailableTitle;

  /// No description provided for @financeChartsUnavailableMessage.
  ///
  /// In es, this message translates to:
  /// **'Los gráficos se habilitarán cuando existan datos verificados de ingresos y gastos.'**
  String get financeChartsUnavailableMessage;

  /// No description provided for @financeNoFabricatedData.
  ///
  /// In es, this message translates to:
  /// **'No se muestran estimaciones ni datos financieros inventados.'**
  String get financeNoFabricatedData;

  /// No description provided for @breakEvenPriceLabel.
  ///
  /// In es, this message translates to:
  /// **'Precio de equilibrio'**
  String get breakEvenPriceLabel;

  /// Etiqueta dentro del círculo del precio de equilibrio
  ///
  /// In es, this message translates to:
  /// **'\$/huevo'**
  String get breakEvenPricePerEggLabel;

  /// Explicación breve junto al círculo del precio de equilibrio
  ///
  /// In es, this message translates to:
  /// **'Costo mínimo de venta para cubrir la operación'**
  String get breakEvenCardDescription;

  /// Porcentaje de margen positivo o negativo
  ///
  /// In es, this message translates to:
  /// **'Margen {value} %'**
  String financeMarginValue(String value);

  /// No description provided for @financeMarginUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Margen no disponible'**
  String get financeMarginUnavailable;

  /// No description provided for @totalCostLabel.
  ///
  /// In es, this message translates to:
  /// **'Costo total'**
  String get totalCostLabel;

  /// No description provided for @goodEggsLabel.
  ///
  /// In es, this message translates to:
  /// **'Huevos buenos'**
  String get goodEggsLabel;

  /// No description provided for @brokenEggsLabel.
  ///
  /// In es, this message translates to:
  /// **'Huevos rotos'**
  String get brokenEggsLabel;

  /// No description provided for @foodCostLabel.
  ///
  /// In es, this message translates to:
  /// **'Costo de alimento'**
  String get foodCostLabel;

  /// No description provided for @totalFeedConsumptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Consumo total'**
  String get totalFeedConsumptionLabel;

  /// No description provided for @weightedAverageBirdsLabel.
  ///
  /// In es, this message translates to:
  /// **'Aves promedio ponderado'**
  String get weightedAverageBirdsLabel;

  /// No description provided for @eggsPerDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Huevos por día'**
  String get eggsPerDayLabel;

  /// No description provided for @eggsPerDayPerBirdLabel.
  ///
  /// In es, this message translates to:
  /// **'Huevos por día por ave'**
  String get eggsPerDayPerBirdLabel;

  /// No description provided for @feedPerDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Consumo por día'**
  String get feedPerDayLabel;

  /// No description provided for @feedPerDayPerBirdLabel.
  ///
  /// In es, this message translates to:
  /// **'Consumo por día por ave'**
  String get feedPerDayPerBirdLabel;

  /// No description provided for @averageSalePriceLabel.
  ///
  /// In es, this message translates to:
  /// **'Precio promedio de venta'**
  String get averageSalePriceLabel;

  /// Resumen compacto de aves y tasas diarias por ave
  ///
  /// In es, this message translates to:
  /// **'{birds} aves • {eggsRate} huevo/(día·ave) • {feedRate} kg/(día·ave)'**
  String financeCompactMetrics(String birds, String eggsRate, String feedRate);

  /// No description provided for @mixtureDurationLabel.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get mixtureDurationLabel;

  /// Duración de una mezcla de alimento en días
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String financeDurationDays(int count);

  /// Cantidad de alimento en kilogramos
  ///
  /// In es, this message translates to:
  /// **'{value} kg'**
  String financeKilograms(String value);

  /// No description provided for @periodLabel.
  ///
  /// In es, this message translates to:
  /// **'Periodo'**
  String get periodLabel;

  /// No description provided for @ongoingLabel.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get ongoingLabel;

  /// No description provided for @notAvailableLabel.
  ///
  /// In es, this message translates to:
  /// **'No disponible'**
  String get notAvailableLabel;

  /// No description provided for @breakEvenUnavailableReason.
  ///
  /// In es, this message translates to:
  /// **'No se registraron huevos buenos para esta mezcla.'**
  String get breakEvenUnavailableReason;

  /// Rango de fechas mostrado en una tarjeta de equilibrio
  ///
  /// In es, this message translates to:
  /// **'{start} – {end}'**
  String financeDateRange(String start, String end);

  /// Resumen accesible de una tarjeta de equilibrio
  ///
  /// In es, this message translates to:
  /// **'{groupName}. Precio de equilibrio por huevo: {price}. {margin}.'**
  String breakEvenCardSemantics(String groupName, String price, String margin);

  /// Propósito de ciclo para producción de huevos
  ///
  /// In es, this message translates to:
  /// **'Postura'**
  String get economicsV2PurposePostura;

  /// Propósito de ciclo para producción y venta de carne
  ///
  /// In es, this message translates to:
  /// **'Carne'**
  String get economicsV2PurposeCarne;

  /// Propósito de ciclo para venta de especímenes ornamentales
  ///
  /// In es, this message translates to:
  /// **'Ornamental'**
  String get economicsV2PurposeOrnamental;

  /// Métrica de costos asignados al ciclo de producción V2
  ///
  /// In es, this message translates to:
  /// **'Costo atribuible'**
  String get economicsV2AttributableCost;

  /// Métrica de ingresos canónicos del ciclo de producción V2
  ///
  /// In es, this message translates to:
  /// **'Ingreso canónico'**
  String get economicsV2CanonicalRevenue;

  /// Métrica de equilibrio del ciclo de producción V2
  ///
  /// In es, this message translates to:
  /// **'Punto de equilibrio'**
  String get economicsV2BreakEven;

  /// Base de cálculo de equilibrio para ciclos de postura
  ///
  /// In es, this message translates to:
  /// **'huevos'**
  String get economicsV2BasisEggs;

  /// Base de cálculo de equilibrio para ciclos de carne
  ///
  /// In es, this message translates to:
  /// **'animales vendidos'**
  String get economicsV2BasisAnimalsSold;

  /// Base de cálculo de equilibrio para ciclos ornamentales
  ///
  /// In es, this message translates to:
  /// **'especímenes vendidos'**
  String get economicsV2BasisSpecimensSold;

  /// Etiqueta accesible para seleccionar el propósito de postura
  ///
  /// In es, this message translates to:
  /// **'Seleccionar propósito: postura'**
  String get economicsV2SelectPurposePostura;

  /// Etiqueta accesible para seleccionar el propósito de carne
  ///
  /// In es, this message translates to:
  /// **'Seleccionar propósito: carne'**
  String get economicsV2SelectPurposeCarne;

  /// Etiqueta accesible para seleccionar el propósito ornamental
  ///
  /// In es, this message translates to:
  /// **'Seleccionar propósito: ornamental'**
  String get economicsV2SelectPurposeOrnamental;

  /// Entrada a los ciclos de producción Economics V2 desde finanzas
  ///
  /// In es, this message translates to:
  /// **'Ciclos de producción'**
  String get economicsV2ProductionCycles;

  /// Etiqueta accesible para abrir los ciclos de producción Economics V2
  ///
  /// In es, this message translates to:
  /// **'Abrir ciclos de producción'**
  String get economicsV2OpenProductionCycles;

  /// Etiquetas localizadas para los pasos del ciclo Economics V2
  ///
  /// In es, this message translates to:
  /// **'{step, select, title{Crear ciclo V2} purpose{Propósito} create{Crear ciclo} created{Ciclo creado} animal{Animal} assign{Asignar animal} assigned{Animal asignado} expense{Monto del gasto} record{Registrar gasto} recorded{Gasto registrado} feed{Mezcla de alimento} link{Vincular alimento} linked{Alimento vinculado} failure{No se pudo completar el paso.} invalid{Ingresa un monto válido.} other{}}'**
  String economicsV2LifecycleStep(String step);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
