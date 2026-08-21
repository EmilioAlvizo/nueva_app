abstract final class AppWidgetKeys {
  static const eggPages = 'eggs.pages';
  static const eggFormSheet = 'eggs.form.sheet';
  static const eggFormDragHandle = 'eggs.form.drag-handle';
  static const eggFormIcon = 'eggs.form.icon';
  static const eggFormSubmit = 'eggs.form.submit';
  static const financeTabs = 'finances.tabs';
  static const financePages = 'finances.pages';
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
  static const financeEconomicsV2Entry = 'finances.economics-v2.entry';
  static const economicsV2PurposePostura =
      'cycles.economics-v2.purpose.postura';
  static const economicsV2PurposeCarne = 'cycles.economics-v2.purpose.carne';
  static const economicsV2PurposeOrnamental =
      'cycles.economics-v2.purpose.ornamental';
  static const economicsV2LifecyclePanel =
      'cycles.economics-v2.lifecycle.panel';
  static const economicsV2LifecyclePurpose =
      'cycles.economics-v2.lifecycle.purpose';
  static const economicsV2LifecycleCreate =
      'cycles.economics-v2.lifecycle.create';
  static const economicsV2LifecycleAnimal =
      'cycles.economics-v2.lifecycle.animal';
  static const economicsV2LifecycleAssignAnimal =
      'cycles.economics-v2.lifecycle.assign-animal';
  static const economicsV2LifecycleExpenseAmount =
      'cycles.economics-v2.lifecycle.expense-amount';
  static const economicsV2LifecycleRecordExpense =
      'cycles.economics-v2.lifecycle.record-expense';
  static const economicsV2LifecycleFeed = 'cycles.economics-v2.lifecycle.feed';
  static const economicsV2LifecycleLinkFeed =
      'cycles.economics-v2.lifecycle.link-feed';

  static String financeBreakEvenCard(String mixtureId) {
    return 'finances.balance.card.$mixtureId';
  }

  static String financeBreakEvenPriceIndicator(String mixtureId) {
    return 'finances.balance.price.$mixtureId';
  }

  static String financeMarginChip(String mixtureId) {
    return 'finances.balance.margin.$mixtureId';
  }

  static String financeBreakEvenDecoration(String mixtureId) {
    return 'finances.balance.decoration.$mixtureId';
  }

  static String financeBreakEvenMetric(String mixtureId, String role) {
    return 'finances.balance.metric.$mixtureId.$role';
  }

  static String financeBreakEvenPeriod(String mixtureId) {
    return 'finances.balance.period.$mixtureId';
  }
}
