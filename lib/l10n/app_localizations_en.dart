// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get financesTitle => 'Finances';

  @override
  String get financeTabBalance => 'Break-even';

  @override
  String get financeTabIncome => 'Income';

  @override
  String get financeTabExpenses => 'Expenses';

  @override
  String get financeTabCharts => 'Charts';

  @override
  String get financeBalanceHeading => 'Break-even by feed mix';

  @override
  String get financeBalanceSubtitle =>
      'Minimum egg price needed to cover the feed cost for each mix.';

  @override
  String get financeErrorTitle => 'We couldn\'t load the break-even data';

  @override
  String get financeErrorMessage => 'Check your connection and try again.';

  @override
  String get financeRetry => 'Try again';

  @override
  String get financeBalanceEmptyTitle => 'No break-even data yet';

  @override
  String get financeBalanceEmptyMessage =>
      'Break-even results will appear when the selected farm has feed mixes with egg production.';

  @override
  String get financeIncomeUnavailableTitle => 'Income is not available yet';

  @override
  String get financeIncomeUnavailableMessage =>
      'This tab is ready for income once a verified data source is defined.';

  @override
  String get financeExpensesUnavailableTitle =>
      'Expenses are not available yet';

  @override
  String get financeExpensesUnavailableMessage =>
      'This tab is ready for expenses once a verified data source is defined.';

  @override
  String get financeChartsUnavailableTitle =>
      'Financial charts are not available yet';

  @override
  String get financeChartsUnavailableMessage =>
      'Charts will be enabled when verified income and expense data is available.';

  @override
  String get financeNoFabricatedData =>
      'No estimates or invented financial data are shown.';

  @override
  String get breakEvenPriceLabel => 'Break-even price';

  @override
  String get goodEggsLabel => 'Good eggs';

  @override
  String get brokenEggsLabel => 'Broken eggs';

  @override
  String get foodCostLabel => 'Feed cost';

  @override
  String get periodLabel => 'Period';

  @override
  String get ongoingLabel => 'Ongoing';

  @override
  String get notAvailableLabel => 'Not available';

  @override
  String get breakEvenUnavailableReason =>
      'No good eggs were recorded for this mix.';

  @override
  String financeDateRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String breakEvenCardSemantics(String groupName, String price) {
    return '$groupName. Break-even price: $price.';
  }
}
