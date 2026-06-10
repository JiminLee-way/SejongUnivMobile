/// 진단/크래시 수집 설정.
class AppDiagnosticsConfig {
  const AppDiagnosticsConfig._();

  /// Sentry DSN. **비어 있으면 Sentry 비활성**(앱은 정상 동작, 자동 크래시 수집만
  /// off). 빌드 시 주입:
  ///   flutter build apk --dart-define=SENTRY_DSN=https://xxx@oyyy.ingest.sentry.io/zzz
  ///
  /// DSN은 비밀이 아니라 클라에 둬도 안전(write-only ingestion key)하지만, 환경
  /// 분리/회전을 위해 소스 상수가 아니라 dart-define으로 받는다. DSN이 없어도
  /// 로컬 링버퍼 + 크래시 영속화 + 다음-실행 프롬프트는 그대로 작동한다.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get sentryEnabled => sentryDsn.isNotEmpty;
}
