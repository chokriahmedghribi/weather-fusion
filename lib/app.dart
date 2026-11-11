import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/home_screen.dart';
import 'ui/privacy_screen.dart';

class WeatherFusionApp extends ConsumerWidget {
  const WeatherFusionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(stringsProvider);
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          brightness: b,
          colorSchemeSeed: const Color(0xFF2F6FDE),
        );
    return MaterialApp(
      title: s.t('app_title'),
      debugShowCheckedModeBanner: false,
      // 'ar' switches the whole app to right-to-left automatically.
      locale: Locale(settings.localeCode),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: settings.themeMode,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      // No location prompt before the user has read the explanation.
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboardingDone));
    return onboarded ? const HomeScreen() : const PrivacyScreen(onboarding: true);
  }
}
