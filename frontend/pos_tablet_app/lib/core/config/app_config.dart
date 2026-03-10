class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const int defaultOutletId = 1;
  static const int defaultWarehouseId = 1;
}
