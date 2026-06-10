/// 앱 강제/권장 업데이트 판정 — Supabase `app_config`(android 행) 매핑.
///
/// 서버가 versionCode(빌드번호) 기준 두 임계값을 내려준다:
///  - [minBuildNumber]    : 이 미만 = 강제(닫기 불가) 업데이트.
///  - [latestBuildNumber] : 이 미만 = 권장(닫기 가능) 업데이트 안내.
///
/// 둘 다 0(시드 기본값)이면 누구도 막히지 않는다 — 기능 휴면 상태. 관리자가
/// 빌드번호만 올리면 APK 재빌드 없이 발동(home_events/facility_images와 동일한
/// 서버 구동 패턴).
enum AppUpdateVerdict { none, recommended, forced }

class AppUpdateConfig {
  const AppUpdateConfig({
    required this.minBuildNumber,
    required this.latestBuildNumber,
    required this.storeUrl,
    this.forceTitle,
    this.forceMessage,
    this.recommendTitle,
    this.recommendMessage,
  });

  final int minBuildNumber;
  final int latestBuildNumber;
  final String storeUrl;
  final String? forceTitle;
  final String? forceMessage;
  final String? recommendTitle;
  final String? recommendMessage;

  factory AppUpdateConfig.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    String? asText(Object? v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return AppUpdateConfig(
      minBuildNumber: asInt(json['min_build_number']),
      latestBuildNumber: asInt(json['latest_build_number']),
      storeUrl: (json['store_url'] ?? '').toString(),
      forceTitle: asText(json['force_title']),
      forceMessage: asText(json['force_message']),
      recommendTitle: asText(json['recommend_title']),
      recommendMessage: asText(json['recommend_message']),
    );
  }

  /// 설치된 빌드번호로 판정. `min`이 `latest`보다 큰 잘못된 설정도 강제 우선으로
  /// 안전하게 처리된다.
  AppUpdateVerdict verdictFor(int currentBuild) {
    if (currentBuild < minBuildNumber) return AppUpdateVerdict.forced;
    if (currentBuild < latestBuildNumber) return AppUpdateVerdict.recommended;
    return AppUpdateVerdict.none;
  }
}
