/// Build-time configuration, injected with `--dart-define-from-file=.env`.
/// Nothing here is read from source code or bundled as a readable asset.
class Env {
  static const openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY');
  static const metNoUserAgent = String.fromEnvironment(
    'MET_NO_USER_AGENT',
    defaultValue: 'WeatherFusion/1.0 (set MET_NO_USER_AGENT in .env)',
  );
}
