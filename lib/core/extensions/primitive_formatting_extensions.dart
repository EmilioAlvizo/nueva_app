import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

const _dotDecimalLocale = 'en_US';

extension DateTimeFormatting on DateTime {
  static DateTime nowLocal() => DateTime.now();

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

  String formatCompactCurrency(AppLocalizations _) {
    return (NumberFormat.currency(
            locale: _dotDecimalLocale,
            symbol: r'$',
            decimalDigits: 2,
          )
          ..minimumFractionDigits = 0
          ..maximumFractionDigits = 2)
        .format(this);
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

extension StringSearchNormalization on String {
  String normalizedForSearch() {
    var normalized = toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
