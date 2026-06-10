class ServiceUrls {
  const ServiceUrls._();

  static const String sejongApi = String.fromEnvironment('SEJONG_API_BASE_URL');
  static const String sejongWeb = String.fromEnvironment('SEJONG_WEB_BASE_URL');
  static const String ucheckApi = String.fromEnvironment('UCHECK_API_BASE_URL');
  static const String libseat = String.fromEnvironment('LIBSEAT_BASE_URL');
  static const String sjpt = String.fromEnvironment('SJPT_BASE_URL');
  static const String happydorm = String.fromEnvironment('HAPPYDORM_BASE_URL');
  static const String androidStoreUrl = String.fromEnvironment(
    'ANDROID_STORE_URL',
  );

  static String join(String base, String path) {
    if (base.isEmpty) return path;
    if (path.isEmpty) return base;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }
}
