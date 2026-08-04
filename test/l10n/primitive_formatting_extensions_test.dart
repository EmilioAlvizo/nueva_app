import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rancho/core/extensions/primitive_formatting_extensions.dart';
import 'package:rancho/l10n/app_localizations_es.dart';

void main() {
  final l10n = AppLocalizationsEs();

  setUpAll(() => initializeDateFormatting('es'));

  test('numeric formats use a decimal point', () {
    expect(12.5.formatDecimal(l10n), '12.5');
    expect((-12.5).formatDecimal(l10n), '-12.5');
    expect(12.5.formatFixedTwoDecimals(l10n), '12.50');
    expect(12.5.formatSignedDecimal(l10n), '+12.5');
    expect((-12.5).formatSignedDecimal(l10n), '-12.5');
    expect(12.5.formatCurrency(l10n), r'$12.50');
    expect((-12.5).formatCurrency(l10n), r'-$12.50');
  });

  test('dates remain naturally Spanish', () {
    expect(DateTime(2026, 7).formatShortDate(l10n), '1 jul 2026');
  });
}
