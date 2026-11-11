import 'package:flutter_test/flutter_test.dart';
import 'package:weather_fusion/core/units.dart';
import 'package:weather_fusion/core/weather_condition.dart';

void main() {
  group('unit conversions', () {
    test('temperature', () {
      expect(Units.cToF(100), 212);
      expect(Units.cToF(-40), -40);
      expect(Units.fToC(32), 0);
      expect(Units.kToC(273.15), closeTo(0, 1e-9));
      expect(Units.temp(20, TempUnit.celsius), 20);
      expect(Units.temp(20, TempUnit.fahrenheit), 68);
    });

    test('wind speed', () {
      expect(Units.msToKmh(10), closeTo(36, 1e-9));
      expect(Units.kmhToMs(36), closeTo(10, 1e-9));
      expect(Units.msToMph(10), closeTo(22.369, 1e-3));
      expect(Units.mphToMs(Units.msToMph(7.3)), closeTo(7.3, 1e-9));
      expect(Units.wind(10, WindUnit.ms), 10);
      expect(Units.wind(10, WindUnit.kmh), closeTo(36, 1e-9));
    });
  });

  group('Beaufort scale', () {
    test('boundaries', () {
      expect(Units.beaufort(0), 0);
      expect(Units.beaufort(0.29), 0);
      expect(Units.beaufort(0.3), 1);
      expect(Units.beaufort(5.4), 3);
      expect(Units.beaufort(5.5), 4);
      expect(Units.beaufort(10.7), 5);
      expect(Units.beaufort(20.8), 9);
      expect(Units.beaufort(32.7), 12);
      expect(Units.beaufort(60), 12);
    });
  });

  group('directions', () {
    test('normalizeDeg wraps into 0..360', () {
      expect(Units.normalizeDeg(-10), 350);
      expect(Units.normalizeDeg(370), 10);
      expect(Units.normalizeDeg(360), 0);
    });

    test('cardinal points', () {
      expect(Units.cardinal(0), 'N');
      expect(Units.cardinal(44), 'NE');
      expect(Units.cardinal(90), 'E');
      expect(Units.cardinal(180), 'S');
      expect(Units.cardinal(270), 'W');
      expect(Units.cardinal(337.4), 'NW');
      expect(Units.cardinal(337.5), 'N');
      expect(Units.cardinal(359.9), 'N');
    });
  });

  test('apparent temperature: humidity warms, wind cools', () {
    expect(Units.apparentTemperature(20, 50, 0), closeTo(19.85, 0.05));
    expect(Units.apparentTemperature(20, 90, 0),
        greaterThan(Units.apparentTemperature(20, 30, 0)));
    expect(Units.apparentTemperature(20, 50, 8),
        lessThan(Units.apparentTemperature(20, 50, 0)));
  });

  group('condition mapping', () {
    test('WMO codes (Open-Meteo)', () {
      expect(conditionFromWmo(0), WeatherCondition.clear);
      expect(conditionFromWmo(2), WeatherCondition.partlyCloudy);
      expect(conditionFromWmo(3), WeatherCondition.cloudy);
      expect(conditionFromWmo(45), WeatherCondition.fog);
      expect(conditionFromWmo(53), WeatherCondition.drizzle);
      expect(conditionFromWmo(63), WeatherCondition.rain);
      expect(conditionFromWmo(65), WeatherCondition.heavyRain);
      expect(conditionFromWmo(75), WeatherCondition.snow);
      expect(conditionFromWmo(95), WeatherCondition.thunderstorm);
      expect(conditionFromWmo(1234), WeatherCondition.unknown);
    });

    test('MET Norway symbols', () {
      expect(conditionFromMetNoSymbol('clearsky_day'), WeatherCondition.clear);
      expect(conditionFromMetNoSymbol('fair_night'), WeatherCondition.partlyCloudy);
      expect(conditionFromMetNoSymbol('cloudy'), WeatherCondition.cloudy);
      expect(conditionFromMetNoSymbol('lightrainshowers_day'), WeatherCondition.rain);
      expect(conditionFromMetNoSymbol('heavyrain'), WeatherCondition.heavyRain);
      expect(conditionFromMetNoSymbol('rainandthunder'), WeatherCondition.thunderstorm);
      expect(conditionFromMetNoSymbol('sleet'), WeatherCondition.snow);
    });

    test('OpenWeather ids', () {
      expect(conditionFromOpenWeatherId(800), WeatherCondition.clear);
      expect(conditionFromOpenWeatherId(802), WeatherCondition.partlyCloudy);
      expect(conditionFromOpenWeatherId(804), WeatherCondition.cloudy);
      expect(conditionFromOpenWeatherId(501), WeatherCondition.rain);
      expect(conditionFromOpenWeatherId(502), WeatherCondition.heavyRain);
      expect(conditionFromOpenWeatherId(211), WeatherCondition.thunderstorm);
      expect(conditionFromOpenWeatherId(741), WeatherCondition.fog);
    });
  });
}
