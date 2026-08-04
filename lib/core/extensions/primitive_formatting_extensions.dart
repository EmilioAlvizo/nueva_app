import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

const _dotDecimalLocale = 'en_US';

extension DateTimeFormatting on DateTime {
  String formatShortDate(AppLocalizations l10n) {
    return DateFormat.yMMMd(l10n.localeName).format(this);
  }
}

extension NumFormatting on num {
  String formatCurrency(AppLocalizations _) {
    return NumberFormat.currency(
      locale: _dotDecimalLocale,
      symbol: r'$',
      decimalDigits: 2,
    ).format(this);
  }

  String formatInteger(AppLocalizations _) {
    return NumberFormat.decimalPattern(_dotDecimalLocale).format(this);
  }

  String formatDecimal(AppLocalizations _, {int maximumFractionDigits = 2}) {
    return (NumberFormat.decimalPattern(_dotDecimalLocale)
          ..minimumFractionDigits = 0
          ..maximumFractionDigits = maximumFractionDigits)
        .format(this);
  }

  String formatFixedTwoDecimals(AppLocalizations _) {
    return NumberFormat('0.00', _dotDecimalLocale).format(this);
  }

  String formatSignedDecimal(
    AppLocalizations _, {
    int maximumFractionDigits = 2,
  }) {
    final formatted =
        (NumberFormat.decimalPattern(_dotDecimalLocale)
              ..minimumFractionDigits = 0
              ..maximumFractionDigits = maximumFractionDigits)
            .format(this);
    return this >= 0 ? '+$formatted' : formatted;
  }
}
