import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

extension DateTimeFormatting on DateTime {
  String formatShortDate(AppLocalizations l10n) {
    return DateFormat.yMMMd(l10n.localeName).format(this);
  }
}

extension NumFormatting on num {
  String formatCurrency(AppLocalizations l10n) {
    return NumberFormat.currency(
      locale: l10n.localeName,
      symbol: r'$',
      decimalDigits: 2,
    ).format(this);
  }

  String formatInteger(AppLocalizations l10n) {
    return NumberFormat.decimalPattern(l10n.localeName).format(this);
  }

  String formatDecimal(AppLocalizations l10n, {int maximumFractionDigits = 2}) {
    return (NumberFormat.decimalPattern(l10n.localeName)
          ..minimumFractionDigits = 0
          ..maximumFractionDigits = maximumFractionDigits)
        .format(this);
  }

  String formatSignedDecimal(
    AppLocalizations l10n, {
    int maximumFractionDigits = 2,
  }) {
    final formatted = formatDecimal(
      l10n,
      maximumFractionDigits: maximumFractionDigits,
    );
    return this >= 0 ? '+$formatted' : formatted;
  }
}
