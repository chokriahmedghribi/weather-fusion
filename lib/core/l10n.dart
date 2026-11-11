import '../models/fused_weather.dart';
import 'units.dart';
import 'weather_condition.dart';

/// Minimal two-language string table (English, Arabic) plus the formatters
/// that turn canonical values into display text. A missing value is always
/// rendered as [na] ("Not available") — never as a made-up number.
class S {
  final String code;
  const S(this.code);

  bool get isAr => code == 'ar';

  String t(String key) => _strings[key]?[isAr ? 1 : 0] ?? key;

  String get na => t('na');

  // ------------------------------------------------------------ formatters

  String temp(double? celsius, TempUnit u) =>
      celsius == null ? na : '${Units.temp(celsius, u).round()}°';

  String tempSuffix(TempUnit u) => u == TempUnit.celsius ? 'C' : 'F';

  String wind(double? ms, WindUnit u) {
    if (ms == null) return na;
    final v = Units.wind(ms, u);
    final text = u == WindUnit.ms ? v.toStringAsFixed(1) : v.round().toString();
    return '$text ${t('unit_${u.name}')}';
  }

  /// [step] rounds to a coarser grid (e.g. 5) where finer digits would
  /// suggest precision the method does not have.
  String percent(double? v, {int step = 1}) =>
      v == null ? na : '${(v / step).round() * step}%';

  String pressure(double? hpa) => hpa == null ? na : '${hpa.round()} hPa';

  String visibility(double? metres) {
    if (metres == null) return na;
    final km = metres / 1000;
    return '${km >= 10 ? km.round() : km.toStringAsFixed(1)} ${t('unit_km')}';
  }

  /// Local time of the device, HH:mm.
  String clock(DateTime time) {
    final l = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  String minutes(int m) => '$m ${t('unit_min')}';

  String ago(Duration d) {
    if (d.inMinutes < 1) return t('just_now');
    if (d.inMinutes < 60) return t('min_ago').replaceFirst('{n}', '${d.inMinutes}');
    return t('hours_ago').replaceFirst('{n}', '${d.inHours}');
  }

  String condition(WeatherCondition c) => t('cond_${c.name}');
  String cardinal(double deg) => t('dir_${Units.cardinal(deg)}');
  String confidence(ConfidenceLevel l) => t('conf_${l.name}');
  String confidenceShort(ConfidenceLevel l) => t('conf_short_${l.name}');
}

// key: [English, Arabic]
const Map<String, List<String>> _strings = {
  'app_title': ['Weather Fusion', 'طقس مدمج'],
  'na': ['Not available', 'غير متوفر'],
  'loading': ['Loading weather…', 'جارٍ جلب الطقس…'],
  'no_data': ['No data to show yet.', 'لا توجد بيانات لعرضها بعد.'],
  'refresh': ['Refresh', 'تحديث'],
  'retry': ['Retry', 'إعادة المحاولة'],
  'settings': ['Settings', 'الإعدادات'],
  'search': ['Search', 'بحث'],
  'my_location': ['My location', 'موقعي الحالي'],
  'choose_city': ['Choose a city', 'اختيار مدينة'],
  'city_name': ['City name', 'اسم المدينة'],
  'no_results': ['No city found.', 'لم يُعثر على مدينة.'],
  'search_failed': ['Search failed. Check your connection.', 'تعذّر البحث. تحقق من الاتصال.'],
  'use_gps': ['Use my location (GPS)', 'استخدام موقعي (GPS)'],
  'use_gps_hint': [
    'The system will ask for permission.',
    'سيطلب النظام الإذن بالوصول إلى الموقع.'
  ],
  'change_location': ['Change location', 'تغيير الموقع'],

  // current
  'feels_like': ['Feels like', 'الإحساس الفعلي'],
  'wind': ['Wind', 'الرياح'],
  'direction': ['Direction', 'الاتجاه'],
  'gusts': ['Gusts', 'الهبّات'],
  'beaufort': ['Beaufort', 'بوفورت'],
  'from': ['from', 'من'],
  'calm': ['Calm', 'ساكنة'],
  'variable': ['Variable (sources disagree)', 'متغيّر (المصادر مختلفة)'],
  'details': ['Details', 'التفاصيل'],
  'humidity': ['Humidity', 'الرطوبة'],
  'pressure': ['Pressure (sea level)', 'الضغط (مستوى البحر)'],
  'visibility': ['Visibility', 'الرؤية'],
  'precip_prob': ['Chance of precipitation', 'احتمال الهطول'],
  'cloud_cover': ['Cloud cover', 'الغطاء السحابي'],
  'phone_barometer': ['Phone barometer (local)', 'بارومتر الهاتف (محلي)'],

  // confidence / why
  'why_title': ['Why this result?', 'لماذا هذه النتيجة؟'],
  'why_text': [
    'Weighted average of the sources by freshness, distance and reliability; '
        'outliers are discarded. Confidence drops with few sources, '
        'disagreement between them, or old data.',
    'متوسط مرجّح للمصادر حسب حداثة البيانات والقرب والموثوقية، مع استبعاد '
        'القيم الشاذة. تنخفض الثقة عند قلة المصادر أو اختلافها أو قِدم البيانات.'
  ],
  'confidence': ['Confidence', 'الثقة'],
  'conf_high': ['High confidence', 'ثقة عالية'],
  'conf_medium': ['Medium confidence', 'ثقة متوسطة'],
  'conf_low': ['Low confidence', 'ثقة منخفضة'],
  'conf_short_high': ['High', 'عالية'],
  'conf_short_medium': ['Med.', 'متوسطة'],
  'conf_short_low': ['Low', 'منخفضة'],
  'last_update': ['Last update', 'آخر تحديث'],
  'sources_used': ['Sources used', 'المصادر المستخدمة'],
  'weight': ['weight', 'الوزن'],
  'data_age': ['data age', 'عمر البيانات'],
  'single_source_note': [
    'Only one source answered: nothing to cross-check against.',
    'مصدر واحد فقط استجاب: لا يمكن التحقق المتقاطع.'
  ],
  'failed_sources': ['Unreachable', 'تعذّر الوصول إلى'],
  'rejected_values': ['Discarded as outliers', 'قيم استُبعدت لشذوذها'],
  'field_temperature': ['temperature', 'الحرارة'],
  'field_humidity': ['humidity', 'الرطوبة'],
  'field_pressure': ['pressure', 'الضغط'],
  'field_windSpeed': ['wind speed', 'سرعة الرياح'],
  'field_windGust': ['gusts', 'الهبّات'],
  'field_cloudCover': ['cloud cover', 'الغطاء السحابي'],
  'field_precipProb': ['precipitation chance', 'احتمال الهطول'],
  'just_now': ['just now', 'الآن'],
  'min_ago': ['{n} min ago', 'منذ {n} د'],
  'hours_ago': ['{n} h ago', 'منذ {n} س'],
  'stale_banner': ['Showing old data.', 'البيانات المعروضة قديمة.'],
  'offline_banner': [
    'Offline — showing saved data.',
    'لا يوجد اتصال — تُعرض البيانات المحفوظة.'
  ],

  // forecast / nowcast
  'next_hours': ['Next hours', 'الساعات القادمة'],
  'temp_chart': ['Temperature, next hours', 'درجة الحرارة في الساعات القادمة'],
  'nowcast_note': [
    'Short-term estimate (1–6 h). The dot shows how much to trust each hour.',
    'تقدير قصير المدى (1–6 ساعات). النقطة الملوّنة تبيّن مقدار الثقة بكل ساعة.'
  ],
  'nowcast_stable': [
    'No significant change expected in the next hours.',
    'لا يُتوقع تغيّر مهم خلال الساعات القادمة.'
  ],
  'nowcast_rainLikely': [
    'Precipitation likely in the next hours.',
    'هطول مرجّح خلال الساعات القادمة.'
  ],
  'nowcast_rainPossible': [
    'Precipitation possible in the next hours.',
    'هطول محتمل خلال الساعات القادمة.'
  ],
  'nowcast_clearing': [
    'Precipitation expected to ease.',
    'يُتوقع انحسار الهطول.'
  ],
  'nowcast_windIncreasing': [
    'Wind expected to strengthen.',
    'يُتوقع اشتداد الرياح.'
  ],
  'nowcast_unavailable': [
    'Short-term forecast not available.',
    'التوقع قصير المدى غير متوفر.'
  ],
  'pressure_trend': ['Pressure trend', 'اتجاه الضغط'],
  'trend_fallingFast': ['falling fast', 'هبوط سريع'],
  'trend_falling': ['falling', 'هبوط'],
  'trend_steady': ['steady', 'مستقر'],
  'trend_rising': ['rising', 'ارتفاع'],
  'trend_risingFast': ['rising fast', 'ارتفاع سريع'],
  'trend_measured': ['measured by phone barometer', 'قياس بارومتر الهاتف'],
  'trend_model': ['from source forecasts', 'من توقعات المصادر'],

  // units
  'unit_kmh': ['km/h', 'كم/س'],
  'unit_ms': ['m/s', 'م/ث'],
  'unit_mph': ['mph', 'ميل/س'],
  'unit_km': ['km', 'كم'],
  'unit_min': ['min', 'د'],

  // conditions
  'cond_clear': ['Clear', 'صافٍ'],
  'cond_partlyCloudy': ['Partly cloudy', 'غائم جزئيًا'],
  'cond_cloudy': ['Cloudy', 'غائم'],
  'cond_fog': ['Fog', 'ضباب'],
  'cond_drizzle': ['Drizzle', 'رذاذ'],
  'cond_rain': ['Rain', 'مطر'],
  'cond_heavyRain': ['Heavy rain', 'مطر غزير'],
  'cond_snow': ['Snow', 'ثلج'],
  'cond_thunderstorm': ['Thunderstorm', 'عاصفة رعدية'],
  'cond_unknown': ['Not available', 'غير متوفر'],

  // compass
  'dir_N': ['N', 'الشمال'],
  'dir_NE': ['NE', 'الشمال الشرقي'],
  'dir_E': ['E', 'الشرق'],
  'dir_SE': ['SE', 'الجنوب الشرقي'],
  'dir_S': ['S', 'الجنوب'],
  'dir_SW': ['SW', 'الجنوب الغربي'],
  'dir_W': ['W', 'الغرب'],
  'dir_NW': ['NW', 'الشمال الغربي'],
  'dir_N_short': ['N', 'ش'],
  'dir_E_short': ['E', 'ق'],
  'dir_S_short': ['S', 'ج'],
  'dir_W_short': ['W', 'غ'],

  // Beaufort scale
  'bft_0': ['Calm', 'سكون'],
  'bft_1': ['Light air', 'هواء خفيف'],
  'bft_2': ['Light breeze', 'نسيم خفيف'],
  'bft_3': ['Gentle breeze', 'نسيم لطيف'],
  'bft_4': ['Moderate breeze', 'نسيم معتدل'],
  'bft_5': ['Fresh breeze', 'نسيم منعش'],
  'bft_6': ['Strong breeze', 'نسيم قوي'],
  'bft_7': ['Near gale', 'رياح شبه عاصفة'],
  'bft_8': ['Gale', 'رياح عاصفة'],
  'bft_9': ['Strong gale', 'عاصفة قوية'],
  'bft_10': ['Storm', 'عاصفة شديدة'],
  'bft_11': ['Violent storm', 'عاصفة عنيفة'],
  'bft_12': ['Hurricane force', 'إعصار'],

  // errors
  'err_noNetwork': ['No network connection.', 'لا يوجد اتصال بالشبكة.'],
  'err_locationServiceOff': [
    'Location services are turned off.',
    'خدمة الموقع متوقفة على الجهاز.'
  ],
  'err_locationDenied': [
    'Location permission was denied. You can choose a city instead.',
    'رُفض إذن الموقع. يمكنك اختيار مدينة يدويًا.'
  ],
  'err_locationDeniedForever': [
    'Location permission is permanently denied. Enable it in the app settings, or choose a city.',
    'إذن الموقع مرفوض نهائيًا. فعّله من إعدادات التطبيق أو اختر مدينة.'
  ],
  'err_locationTimeout': [
    'Could not get a position in time.',
    'تعذّر تحديد الموقع في الوقت المحدد.'
  ],
  'err_locationUnknown': ['Could not determine the location.', 'تعذّر تحديد الموقع.'],
  'err_noLocationChosen': ['No location chosen yet.', 'لم يُحدَّد موقع بعد.'],
  'err_noSourcesEnabled': [
    'No weather source is enabled. Enable one in Settings.',
    'لا يوجد مصدر طقس مفعّل. فعّل مصدرًا من الإعدادات.'
  ],
  'err_allSourcesFailed': [
    'All weather sources failed. Will retry automatically.',
    'فشلت كل مصادر الطقس. ستُعاد المحاولة تلقائيًا.'
  ],
  'err_unknown': ['Something went wrong.', 'حدث خطأ غير متوقع.'],
  'open_app_settings': ['App settings', 'إعدادات التطبيق'],
  'open_location_settings': ['Location settings', 'إعدادات الموقع'],

  // settings
  'set_temperature': ['Temperature', 'درجة الحرارة'],
  'set_wind': ['Wind speed', 'سرعة الرياح'],
  'set_language': ['Language', 'اللغة'],
  'set_theme': ['Appearance', 'المظهر'],
  'set_sources': ['Data sources', 'مصادر البيانات'],
  'set_location': ['Location', 'الموقع'],
  'theme_system': ['System', 'النظام'],
  'theme_light': ['Light', 'فاتح'],
  'theme_dark': ['Dark', 'داكن'],
  'source_needs_key': [
    'Needs an API key in .env',
    'يحتاج مفتاح API في ملف ‎.env'
  ],

  // privacy / permissions
  'privacy_title': ['Permissions & privacy', 'الأذونات والخصوصية'],
  'privacy_intro': [
    'Before you start, here is exactly what the app does with your data.',
    'قبل البدء، هذا ما يفعله التطبيق ببياناتك بالضبط.'
  ],
  'privacy_location': [
    'Location is used only to fetch the weather where you are. It is optional: you can type a city instead.',
    'يُستخدم الموقع لجلب طقس مكانك فقط. وهو اختياري: يمكنك كتابة اسم مدينة بدلًا منه.'
  ],
  'privacy_sharing': [
    'Only approximate coordinates (about 1 km) are sent, and only to the weather sources you enabled.',
    'تُرسل إحداثيات تقريبية فقط (نحو 1 كم)، وإلى مصادر الطقس التي فعّلتها دون غيرها.'
  ],
  'privacy_storage': [
    'Your exact position, settings and last weather data are stored on this device only.',
    'موقعك الدقيق وإعداداتك وآخر بيانات الطقس تُحفظ على هذا الجهاز فقط.'
  ],
  'privacy_sensors': [
    'If your phone has a barometer, it is read to detect pressure changes. Phones cannot measure wind: wind comes from the weather sources.',
    'إن وُجد بارومتر في هاتفك فسيُقرأ لرصد تغيّر الضغط. الهاتف لا يقيس الرياح: بيانات الرياح تأتي من مصادر الطقس.'
  ],
  'privacy_none': [
    'No account, no ads, no analytics, no tracking.',
    'لا حساب، لا إعلانات، لا تحليلات، لا تتبّع.'
  ],
  'allow_location': ['Use my location', 'استخدام موقعي'],
  'enter_city_instead': ['Enter a city instead', 'إدخال مدينة يدويًا'],
};
