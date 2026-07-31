import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/l10n/app_localizations.dart';

void main() {
  test('Spanish is the only generated locale', () {
    expect(AppLocalizations.supportedLocales, const [Locale('es')]);
    expect(AppLocalizations.delegate.isSupported(const Locale('es')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isFalse);
    expect(
      () => lookupAppLocalizations(const Locale('en')),
      throwsFlutterError,
    );
  });

  test('English localization artifacts do not exist', () {
    expect(File('lib/l10n/app_en.arb').existsSync(), isFalse);
    expect(File('lib/l10n/app_localizations_en.dart').existsSync(), isFalse);
  });
}
