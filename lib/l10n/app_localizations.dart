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

  /// No description provided for @economicsV2LifecycleTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear ciclo V2'**
  String get economicsV2LifecycleTitle;

  /// No description provided for @economicsV2LifecyclePurpose.
  ///
  /// In es, this message translates to:
  /// **'Propósito'**
  String get economicsV2LifecyclePurpose;

  /// No description provided for @economicsV2LifecycleCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear ciclo'**
  String get economicsV2LifecycleCreate;

  /// No description provided for @economicsV2LifecycleCreated.
  ///
  /// In es, this message translates to:
  /// **'Ciclo creado'**
  String get economicsV2LifecycleCreated;

  /// No description provided for @economicsV2LifecycleAnimal.
  ///
  /// In es, this message translates to:
  /// **'Animal'**
  String get economicsV2LifecycleAnimal;

  /// No description provided for @economicsV2LifecycleAssignAnimal.
  ///
  /// In es, this message translates to:
  /// **'Asignar animal'**
  String get economicsV2LifecycleAssignAnimal;

  /// No description provided for @economicsV2LifecycleAnimalAssigned.
  ///
  /// In es, this message translates to:
  /// **'Animal asignado'**
  String get economicsV2LifecycleAnimalAssigned;

  /// No description provided for @economicsV2LifecycleExpense.
  ///
  /// In es, this message translates to:
  /// **'Monto del gasto'**
  String get economicsV2LifecycleExpense;

  /// No description provided for @economicsV2LifecycleRecordExpense.
  ///
  /// In es, this message translates to:
  /// **'Registrar gasto'**
  String get economicsV2LifecycleRecordExpense;

  /// No description provided for @economicsV2LifecycleExpenseRecorded.
  ///
  /// In es, this message translates to:
  /// **'Gasto registrado'**
  String get economicsV2LifecycleExpenseRecorded;

  /// No description provided for @economicsV2LifecycleFeed.
  ///
  /// In es, this message translates to:
  /// **'Mezcla de alimento'**
  String get economicsV2LifecycleFeed;

  /// No description provided for @economicsV2LifecycleLinkFeed.
  ///
  /// In es, this message translates to:
  /// **'Vincular alimento'**
  String get economicsV2LifecycleLinkFeed;

  /// No description provided for @economicsV2LifecycleFeedLinked.
  ///
  /// In es, this message translates to:
  /// **'Alimento vinculado'**
  String get economicsV2LifecycleFeedLinked;

  /// No description provided for @economicsV2LifecycleFailure.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar el paso.'**
  String get economicsV2LifecycleFailure;

  /// No description provided for @economicsV2LifecycleInvalidExpense.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un monto válido.'**
  String get economicsV2LifecycleInvalidExpense;
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
