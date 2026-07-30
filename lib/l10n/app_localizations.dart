import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Title of the finances section
  ///
  /// In en, this message translates to:
  /// **'Finances'**
  String get financesTitle;

  /// No description provided for @financeTabBalance.
  ///
  /// In en, this message translates to:
  /// **'Break-even'**
  String get financeTabBalance;

  /// No description provided for @financeTabIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get financeTabIncome;

  /// No description provided for @financeTabExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get financeTabExpenses;

  /// No description provided for @financeTabCharts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get financeTabCharts;

  /// No description provided for @financeBalanceHeading.
  ///
  /// In en, this message translates to:
  /// **'Break-even by feed mix'**
  String get financeBalanceHeading;

  /// No description provided for @financeBalanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Minimum egg price needed to cover the feed cost for each mix.'**
  String get financeBalanceSubtitle;

  /// No description provided for @financeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'\'t load the break-even data'**
  String get financeErrorTitle;

  /// No description provided for @financeErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get financeErrorMessage;

  /// No description provided for @financeRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get financeRetry;

  /// No description provided for @financeBalanceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No break-even data yet'**
  String get financeBalanceEmptyTitle;

  /// No description provided for @financeBalanceEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Break-even results will appear when the selected farm has feed mixes with egg production.'**
  String get financeBalanceEmptyMessage;

  /// No description provided for @financeIncomeUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Income is not available yet'**
  String get financeIncomeUnavailableTitle;

  /// No description provided for @financeIncomeUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This tab is ready for income once a verified data source is defined.'**
  String get financeIncomeUnavailableMessage;

  /// No description provided for @financeExpensesUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses are not available yet'**
  String get financeExpensesUnavailableTitle;

  /// No description provided for @financeExpensesUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This tab is ready for expenses once a verified data source is defined.'**
  String get financeExpensesUnavailableMessage;

  /// No description provided for @financeChartsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial charts are not available yet'**
  String get financeChartsUnavailableTitle;

  /// No description provided for @financeChartsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Charts will be enabled when verified income and expense data is available.'**
  String get financeChartsUnavailableMessage;

  /// No description provided for @financeNoFabricatedData.
  ///
  /// In en, this message translates to:
  /// **'No estimates or invented financial data are shown.'**
  String get financeNoFabricatedData;

  /// No description provided for @breakEvenPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Break-even price'**
  String get breakEvenPriceLabel;

  /// Label inside the break-even price ring
  ///
  /// In en, this message translates to:
  /// **'Break-even price per egg'**
  String get breakEvenPricePerEggLabel;

  /// Short explanation beside the break-even price ring
  ///
  /// In en, this message translates to:
  /// **'Minimum price per good egg needed to cover feed costs.'**
  String get breakEvenCardDescription;

  /// Positive or negative margin percentage chip
  ///
  /// In en, this message translates to:
  /// **'Margin {value}%'**
  String financeMarginValue(String value);

  /// No description provided for @financeMarginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Margin unavailable'**
  String get financeMarginUnavailable;

  /// No description provided for @totalCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get totalCostLabel;

  /// No description provided for @goodEggsLabel.
  ///
  /// In en, this message translates to:
  /// **'Good eggs'**
  String get goodEggsLabel;

  /// No description provided for @brokenEggsLabel.
  ///
  /// In en, this message translates to:
  /// **'Broken eggs'**
  String get brokenEggsLabel;

  /// No description provided for @foodCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Feed cost'**
  String get foodCostLabel;

  /// No description provided for @totalFeedConsumptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Total consumption'**
  String get totalFeedConsumptionLabel;

  /// No description provided for @weightedAverageBirdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Weighted average birds'**
  String get weightedAverageBirdsLabel;

  /// No description provided for @eggsPerDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Eggs per day'**
  String get eggsPerDayLabel;

  /// No description provided for @eggsPerDayPerBirdLabel.
  ///
  /// In en, this message translates to:
  /// **'Eggs per day per bird'**
  String get eggsPerDayPerBirdLabel;

  /// No description provided for @feedPerDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Consumption per day'**
  String get feedPerDayLabel;

  /// No description provided for @feedPerDayPerBirdLabel.
  ///
  /// In en, this message translates to:
  /// **'Consumption per day per bird'**
  String get feedPerDayPerBirdLabel;

  /// No description provided for @averageSalePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Average sale price'**
  String get averageSalePriceLabel;

  /// No description provided for @mixtureDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get mixtureDurationLabel;

  /// Duration of a feed mixture in days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String financeDurationDays(int count);

  /// A localized feed quantity in kilograms
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String financeKilograms(String value);

  /// No description provided for @periodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get periodLabel;

  /// No description provided for @ongoingLabel.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoingLabel;

  /// No description provided for @notAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailableLabel;

  /// No description provided for @breakEvenUnavailableReason.
  ///
  /// In en, this message translates to:
  /// **'No good eggs were recorded for this mix.'**
  String get breakEvenUnavailableReason;

  /// Date range shown on a break-even card
  ///
  /// In en, this message translates to:
  /// **'{start} - {end}'**
  String financeDateRange(String start, String end);

  /// Accessibility summary for a break-even card
  ///
  /// In en, this message translates to:
  /// **'{groupName}. Break-even price per egg: {price}. {margin}.'**
  String breakEvenCardSemantics(String groupName, String price, String margin);
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
