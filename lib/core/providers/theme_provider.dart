import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Theme notifier (Notifier API) ───────────────────────────────────────────
// true = dark, false = light
class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() => true; // dark by default

  void setDark()  => state = true;
  void setLight() => state = false;
  void toggle()   => state = !state;
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);