import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_fusion/core/l10n.dart';
import 'package:weather_fusion/core/units.dart';
import 'package:weather_fusion/core/weather_condition.dart';
import 'package:weather_fusion/models/fused_weather.dart';
import 'package:weather_fusion/ui/widgets/current_card.dart';
import 'package:weather_fusion/ui/widgets/details_card.dart';
import 'package:weather_fusion/ui/widgets/wind_card.dart';

Widget host(Widget child, String locale) => MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  final time = DateTime.utc(2026, 1, 1, 12);

  testWidgets('WindCard (Arabic, RTL): speed, direction, Beaufort, missing gusts',
      (tester) async {
    await tester.pumpWidget(host(
      WindCard(
        weather: FusedWeather(time: time, windSpeedMs: 5, windDirDeg: 315),
        s: const S('ar'),
        windUnit: WindUnit.kmh,
      ),
      'ar',
    ));
    await tester.pumpAndSettle();

    expect(find.text('18 كم/س'), findsOneWidget);
    expect(find.textContaining('الشمال الغربي'), findsOneWidget);
    expect(find.textContaining('3 —'), findsOneWidget); // Beaufort 3
    expect(find.text('غير متوفر'), findsOneWidget); // gusts are not invented
    expect(find.byType(CustomPaint), findsWidgets); // compass
    expect(Directionality.of(tester.element(find.byType(WindCard))),
        TextDirection.rtl);
  });

  testWidgets('WindCard converts units', (tester) async {
    await tester.pumpWidget(host(
      WindCard(
        weather: FusedWeather(time: time, windSpeedMs: 10, windDirDeg: 90, windGustMs: 15),
        s: const S('en'),
        windUnit: WindUnit.mph,
      ),
      'en',
    ));
    await tester.pumpAndSettle();
    expect(find.text('22 mph'), findsOneWidget);
    expect(find.text('34 mph'), findsOneWidget);
    expect(find.textContaining('from E'), findsOneWidget);
  });

  testWidgets('CurrentCard shows temperature in the chosen unit', (tester) async {
    await tester.pumpWidget(host(
      CurrentCard(
        weather: FusedWeather(
            time: time, temperatureC: 20, condition: WeatherCondition.clear),
        s: const S('en'),
        tempUnit: TempUnit.fahrenheit,
      ),
      'en',
    ));
    await tester.pumpAndSettle();
    expect(find.text('68°F'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.textContaining('Not available'), findsOneWidget); // feels-like
  });

  testWidgets('DetailsCard says "not available" instead of showing fake values',
      (tester) async {
    await tester.pumpWidget(host(
      DetailsCard(
        weather: FusedWeather(time: time, humidityPct: 61.6),
        s: const S('ar'),
      ),
      'ar',
    ));
    await tester.pumpAndSettle();
    expect(find.text('62%'), findsOneWidget);
    // pressure, visibility, precipitation, cloud cover, phone barometer
    expect(find.text('غير متوفر'), findsNWidgets(5));
  });
}
