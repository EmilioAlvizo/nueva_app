abstract final class AppWidgetKeys {
  static const financeTabs = 'finances.tabs';
  static const financeBalanceTab = 'finances.tab.balance';
  static const financeIncomeTab = 'finances.tab.income';
  static const financeExpensesTab = 'finances.tab.expenses';
  static const financeChartsTab = 'finances.tab.charts';
  static const financeLoading = 'finances.balance.loading';
  static const financeError = 'finances.balance.error';
  static const financeRetry = 'finances.balance.retry';
  static const financeEmpty = 'finances.balance.empty';
  static const financeIncomeUnavailable = 'finances.income.unavailable';
  static const financeExpensesUnavailable = 'finances.expenses.unavailable';
  static const financeChartsUnavailable = 'finances.charts.unavailable';

  static String financeBreakEvenCard(String mixtureId) {
    return 'finances.balance.card.$mixtureId';
  }

  static String financeBreakEvenPriceIndicator(String mixtureId) {
    return 'finances.balance.price.$mixtureId';
  }

  static String financeMarginChip(String mixtureId) {
    return 'finances.balance.margin.$mixtureId';
  }
}
