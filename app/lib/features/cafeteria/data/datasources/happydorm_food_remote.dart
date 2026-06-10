import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/happydorm_models.dart';

/// 행복기숙사 주간식단 클라이언트.
/// 인증·쿠키 jar 불필요. 기본 API와 헤더가 달라 별도 [Dio] 를 사용한다.
class HappydormFoodRemote {
  HappydormFoodRemote({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              // 서버는 본문이 JSON 인데 헤더는 `text/html;charset=UTF-8` 로
              // 응답한다(서버 버그성). Dio 의 자동 ResponseType.json 매칭이
              // 안 먹어 body가 String 으로 들어오므로 `plain`으로 받고
              // [fetchWeeklyMenu] 에서 직접 jsonDecode.
              responseType: ResponseType.plain,
              headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'Accept': 'application/json, text/plain, */*',
                'Referer': ServiceUrls.join(baseUrl, '/60/6050.do'),
              },
            ),
          );

  static const String baseUrl = ServiceUrls.happydorm;
  static const String _path = '/food/getWeeklyMenu.do';

  final Dio dio;

  /// 주간 식단. [yyyyMmDd] 가 비어 있으면 서버가 "이번 주"를 반환한다.
  /// 빈 응답(`WEEKLYMENU: []`) → [HappydormWeeklyMenu.empty] — 호출자에서
  /// "아직 업로드되지 않았다" UI 분기.
  ///
  /// **GET + query params** — 서버가 query string으로만 정상 응답.
  /// (POST body 형태는 환경에 따라 빈 응답이 옴.)
  Future<HappydormWeeklyMenu> fetchWeeklyMenu({String yyyyMmDd = ''}) async {
    final res = await dio.get<dynamic>(
      _path,
      queryParameters: {'locgbn': 'SJ', 'sch_date': yyyyMmDd},
    );
    final body = res.data;
    dynamic raw;
    if (body is String) {
      if (body.trim().isEmpty) return HappydormWeeklyMenu.empty;
      try {
        raw = jsonDecode(body);
      } catch (_) {
        return HappydormWeeklyMenu.empty;
      }
    } else {
      raw = body;
    }
    if (raw is! Map) return HappydormWeeklyMenu.empty;
    return HappydormWeeklyMenu.fromJson(raw.cast<String, dynamic>());
  }
}
