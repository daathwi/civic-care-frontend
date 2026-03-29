double? _numToDouble(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int? _numToInt(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

/// Ward weather and air quality from backend (Open-Meteo).
class WardWeather {
  final String wardId;
  final String wardName;
  final WardAirQuality airQuality;
  final WardWeatherData weather;

  const WardWeather({
    required this.wardId,
    required this.wardName,
    required this.airQuality,
    required this.weather,
  });

  factory WardWeather.fromJson(Map<String, dynamic> json) {
    final aq = json['air_quality'] as Map<String, dynamic>? ?? {};
    final wth = json['weather'] as Map<String, dynamic>? ?? {};
    return WardWeather(
      wardId: json['ward_id'] as String? ?? '',
      wardName: json['ward_name'] as String? ?? '',
      airQuality: WardAirQuality.fromJson(aq),
      weather: WardWeatherData.fromJson(wth),
    );
  }
}

/// Current weather snapshot (from Open-Meteo current).
class CurrentWeather {
  final double temperature;
  final int humidity;
  final double apparentTemperature;
  final int weatherCode;
  final double windSpeed;
  final int windDirection;
  final double? windGusts;
  final double? pressure;
  final int? cloudCover;
  final bool isDay;

  const CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.apparentTemperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
    this.windGusts,
    this.pressure,
    this.cloudCover,
    required this.isDay,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CurrentWeather(
      temperature: 0, humidity: 0, apparentTemperature: 0,
      weatherCode: 0, windSpeed: 0, windDirection: 0, isDay: true,
    );
    return CurrentWeather(
      temperature: _numToDouble(json['temperature_2m'] ?? json['temperature']) ?? 0,
      humidity: _numToInt(json['relative_humidity_2m'] ?? json['relative_humidity']) ?? 0,
      apparentTemperature: (json['apparent_temperature'] as num?)?.toDouble() ?? 0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      windSpeed: _numToDouble(json['wind_speed_10m'] ?? json['wind_speed']) ?? 0,
      windDirection: _numToInt(json['wind_direction_10m'] ?? json['wind_direction']) ?? 0,
      windGusts: _numToDouble(json['wind_gusts_10m'] ?? json['wind_gusts']),
      pressure: _numToDouble(json['pressure_msl']),
      cloudCover: _numToInt(json['cloud_cover']),
      isDay: (_numToInt(json['is_day']) ?? 0) == 1,
    );
  }
}

/// Daily forecast (7 days).
class DailyForecast {
  final String date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final String? sunrise;
  final String? sunset;
  final double? uvIndexMax;
  final double? precipitationSum;
  final int? precipProbMax;
  final double? windSpeedMax;

  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    this.sunrise,
    this.sunset,
    this.uvIndexMax,
    this.precipitationSum,
    this.precipProbMax,
    this.windSpeedMax,
  });

  static DailyForecast fromJsonAt(Map<String, dynamic> weatherJson, int i) {
    final d = weatherJson['daily'] as Map<String, dynamic>? ?? {};
    final timeList = d['time'] as List? ?? [];
    final codeList = d['weather_code'] as List? ?? [];
    final maxList = d['temperature_2m_max'] as List? ?? [];
    final minList = d['temperature_2m_min'] as List? ?? [];
    final sunriseList = d['sunrise'] as List? ?? [];
    final sunsetList = d['sunset'] as List? ?? [];
    final uvList = d['uv_index_max'] as List? ?? [];
    final precipList = d['precipitation_sum'] as List? ?? [];
    final probList = d['precipitation_probability_max'] as List? ?? [];
    final windList = d['wind_speed_10m_max'] as List? ?? [];
    return DailyForecast(
      date: i < timeList.length ? timeList[i].toString() : '',
      weatherCode: i < codeList.length ? (codeList[i] as num?)?.toInt() ?? 0 : 0,
      tempMax: i < maxList.length ? (maxList[i] as num?)?.toDouble() ?? 0 : 0,
      tempMin: i < minList.length ? (minList[i] as num?)?.toDouble() ?? 0 : 0,
      sunrise: i < sunriseList.length ? sunriseList[i]?.toString() : null,
      sunset: i < sunsetList.length ? sunsetList[i]?.toString() : null,
      uvIndexMax: i < uvList.length ? (uvList[i] as num?)?.toDouble() : null,
      precipitationSum: i < precipList.length ? (precipList[i] as num?)?.toDouble() : null,
      precipProbMax: i < probList.length ? (probList[i] as num?)?.toInt() : null,
      windSpeedMax: i < windList.length ? (windList[i] as num?)?.toDouble() : null,
    );
  }
}

class WardAirQuality {
  final List<String> time;
  final List<double?> pm10;
  final List<double?> pm25;
  final List<int?> usAqi;
  final List<double?> no2;
  final List<double?> ozone;

  const WardAirQuality({
    required this.time,
    required this.pm10,
    required this.pm25,
    required this.usAqi,
    required this.no2,
    required this.ozone,
  });

  factory WardAirQuality.fromJson(Map<String, dynamic> json) {
    final h = json['hourly'] as Map<String, dynamic>? ?? {};
    return WardAirQuality(
      time: _toStrList(h['time']),
      pm10: _toDoubleList(h['pm10']),
      pm25: _toDoubleList(h['pm2_5']),
      usAqi: _toIntList(h['us_aqi_pm2_5']),
      no2: _toDoubleList(h['nitrogen_dioxide']),
      ozone: _toDoubleList(h['ozone']),
    );
  }

  static List<String> _toStrList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static List<double?> _toDoubleList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) => e == null ? null : (e is num ? e.toDouble() : double.tryParse(e.toString()))).toList();
    }
    return [];
  }

  static List<int?> _toIntList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) => e == null ? null : (e is num ? e.toInt() : int.tryParse(e.toString()))).toList();
    }
    return [];
  }

  /// Current (first non-null) US AQI, or null.
  int? get currentAqi {
    for (final v in usAqi) {
      if (v != null) return v;
    }
    return null;
  }

  /// Current PM2.5 (μg/m³).
  double? get currentPm25 {
    for (final v in pm25) {
      if (v != null) return v;
    }
    return null;
  }

  /// Current PM10 (μg/m³).
  double? get currentPm10 {
    for (final v in pm10) {
      if (v != null) return v;
    }
    return null;
  }
}

class WardWeatherData {
  final CurrentWeather? current;
  final List<String> time;
  final List<double?> temperature;
  final List<int?> humidity;
  final List<int?> precipitationProb;
  final List<double?> precipitation;
  final List<int?> weatherCode;
  final List<double?> windSpeed;
  final List<double?> cloudCover;
  final List<DailyForecast> daily;

  const WardWeatherData({
    this.current,
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.precipitationProb,
    this.precipitation = const [],
    this.weatherCode = const [],
    this.windSpeed = const [],
    this.cloudCover = const [],
    this.daily = const [],
  });

  factory WardWeatherData.fromJson(Map<String, dynamic> json) {
    final h = json['hourly'] as Map<String, dynamic>? ?? {};
    final d = json['daily'] as Map<String, dynamic>? ?? {};
    final timeList = WardAirQuality._toStrList(d['time']);
    final dailyList = <DailyForecast>[];
    for (var i = 0; i < timeList.length; i++) {
      dailyList.add(DailyForecast.fromJsonAt(json, i));
    }
    return WardWeatherData(
      current: CurrentWeather.fromJson(json['current'] as Map<String, dynamic>?),
      time: WardAirQuality._toStrList(h['time']),
      temperature: WardAirQuality._toDoubleList(h['temperature_2m']),
      humidity: WardAirQuality._toIntList(h['relative_humidity_2m']),
      precipitationProb: WardAirQuality._toIntList(h['precipitation_probability']),
      precipitation: WardAirQuality._toDoubleList(h['precipitation']),
      weatherCode: WardAirQuality._toIntList(h['weather_code']),
      windSpeed: WardAirQuality._toDoubleList(h['wind_speed_10m']),
      cloudCover: WardAirQuality._toDoubleList(h['cloud_cover']),
      daily: dailyList,
    );
  }

  double? get currentTemp => current?.temperature;

  int? get currentHumidity => current?.humidity;

  double? get currentWindSpeed => current?.windSpeed;

  double? get currentPressure => current?.pressure;

  int get currentWeatherCode => current?.weatherCode ?? 0;
}

/// US EPA AQI level and color for UI.
enum AqiLevel {
  good,
  moderate,
  unhealthySensitive,
  unhealthy,
  veryUnhealthy,
  hazardous,
}

AqiLevel aqiToLevel(int? aqi) {
  if (aqi == null) return AqiLevel.good;
  if (aqi <= 50) return AqiLevel.good;
  if (aqi <= 100) return AqiLevel.moderate;
  if (aqi <= 150) return AqiLevel.unhealthySensitive;
  if (aqi <= 200) return AqiLevel.unhealthy;
  if (aqi <= 300) return AqiLevel.veryUnhealthy;
  return AqiLevel.hazardous;
}

String aqiLevelLabel(AqiLevel level) {
  switch (level) {
    case AqiLevel.good:
      return 'Good';
    case AqiLevel.moderate:
      return 'Moderate';
    case AqiLevel.unhealthySensitive:
      return 'Unhealthy (Sensitive)';
    case AqiLevel.unhealthy:
      return 'Unhealthy';
    case AqiLevel.veryUnhealthy:
      return 'Very Unhealthy';
    case AqiLevel.hazardous:
      return 'Hazardous';
  }
}

/// WMO weather code to description (Open-Meteo).
String weatherCodeLabel(int code) {
  if (code == 0) return 'Clear';
  if (code <= 3) return 'Partly cloudy';
  if (code <= 49) return 'Foggy';
  if (code <= 59) return 'Drizzle';
  if (code <= 69) return 'Rain';
  if (code <= 79) return 'Snow';
  if (code <= 84) return 'Showers';
  if (code <= 94) return 'Snow showers';
  return 'Thunderstorm';
}
