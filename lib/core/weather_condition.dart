enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  heavyRain,
  snow,
  thunderstorm,
  unknown,
}

/// Coarse families used to measure agreement between sources:
/// "rain" vs "heavy rain" is a small disagreement, "clear" vs "rain" is not.
enum ConditionGroup { dry, fog, liquid, snow, thunder, unknown }

extension WeatherConditionX on WeatherCondition {
  bool get isPrecipitation => switch (this) {
        WeatherCondition.drizzle ||
        WeatherCondition.rain ||
        WeatherCondition.heavyRain ||
        WeatherCondition.snow ||
        WeatherCondition.thunderstorm =>
          true,
        _ => false,
      };

  ConditionGroup get group => switch (this) {
        WeatherCondition.clear ||
        WeatherCondition.partlyCloudy ||
        WeatherCondition.cloudy =>
          ConditionGroup.dry,
        WeatherCondition.fog => ConditionGroup.fog,
        WeatherCondition.drizzle ||
        WeatherCondition.rain ||
        WeatherCondition.heavyRain =>
          ConditionGroup.liquid,
        WeatherCondition.snow => ConditionGroup.snow,
        WeatherCondition.thunderstorm => ConditionGroup.thunder,
        WeatherCondition.unknown => ConditionGroup.unknown,
      };
}

/// WMO weather interpretation codes (used by Open-Meteo).
WeatherCondition conditionFromWmo(int code) {
  if (code == 0) return WeatherCondition.clear;
  if (code == 1 || code == 2) return WeatherCondition.partlyCloudy;
  if (code == 3) return WeatherCondition.cloudy;
  if (code == 45 || code == 48) return WeatherCondition.fog;
  if (code >= 51 && code <= 57) return WeatherCondition.drizzle;
  if (code == 65 || code == 82) return WeatherCondition.heavyRain;
  if ((code >= 61 && code <= 67) || code == 80 || code == 81) {
    return WeatherCondition.rain;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return WeatherCondition.snow;
  }
  if (code >= 95 && code <= 99) return WeatherCondition.thunderstorm;
  return WeatherCondition.unknown;
}

/// MET Norway symbol codes, e.g. "partlycloudy_day", "lightrainshowers_night".
WeatherCondition conditionFromMetNoSymbol(String symbol) {
  final s = symbol.split('_').first.toLowerCase();
  if (s.contains('thunder')) return WeatherCondition.thunderstorm;
  if (s.contains('snow') || s.contains('sleet')) return WeatherCondition.snow;
  if (s.contains('heavyrain')) return WeatherCondition.heavyRain;
  if (s.contains('rain')) return WeatherCondition.rain;
  if (s.contains('fog')) return WeatherCondition.fog;
  if (s == 'clearsky') return WeatherCondition.clear;
  if (s == 'fair' || s == 'partlycloudy') return WeatherCondition.partlyCloudy;
  if (s == 'cloudy') return WeatherCondition.cloudy;
  return WeatherCondition.unknown;
}

/// OpenWeather condition ids (https://openweathermap.org/weather-conditions).
WeatherCondition conditionFromOpenWeatherId(int id) {
  if (id >= 200 && id < 300) return WeatherCondition.thunderstorm;
  if (id >= 300 && id < 400) return WeatherCondition.drizzle;
  if (id == 502 || id == 503 || id == 504 || id == 522 || id == 531) {
    return WeatherCondition.heavyRain;
  }
  if (id >= 500 && id < 600) return WeatherCondition.rain;
  if (id >= 600 && id < 700) return WeatherCondition.snow;
  if (id >= 700 && id < 800) return WeatherCondition.fog;
  if (id == 800) return WeatherCondition.clear;
  if (id == 801 || id == 802) return WeatherCondition.partlyCloudy;
  if (id == 803 || id == 804) return WeatherCondition.cloudy;
  return WeatherCondition.unknown;
}
