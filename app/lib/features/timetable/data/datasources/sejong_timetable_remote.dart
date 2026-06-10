import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';

/// `/api/secureapi/class-schedule/*` 3개 endpoint 호출.
///
/// envelope 풀린 raw `data` payload를 그대로 반환 — DTO 매핑/그룹핑은
/// 위 레이어 [SejongTimetableMapper] 책임.
class SejongTimetableRemote {
  SejongTimetableRemote({required this.client});
  final SejongApiClient client;

  /// `[{year, smtCd}]` 배열.
  Future<List<Map<String, dynamic>>> fetchAvailableSemesters() async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.availableSemesters,
    );
    return client.unwrap<List<Map<String, dynamic>>>(
      res,
      (raw) => (raw as List).cast<Map<String, dynamic>>(),
    );
  }

  /// `{year, smtCd, courses: [...], cyberLectures: [...]}`.
  Future<Map<String, dynamic>> fetchTimetable({
    required String year,
    required String smtCd,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.timetable,
      queryParameters: {'year': year, 'smtCd': smtCd},
    );
    return client.unwrap<Map<String, dynamic>>(
      res,
      (raw) => (raw as Map).cast<String, dynamic>(),
    );
  }

  /// `{courses: [...], creditSummary: {...}}`.
  Future<Map<String, dynamic>> fetchEnrolledCourses({
    required String year,
    required String smtCd,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.enrolledCourses,
      queryParameters: {'year': year, 'smtCd': smtCd},
    );
    return client.unwrap<Map<String, dynamic>>(
      res,
      (raw) => (raw as Map).cast<String, dynamic>(),
    );
  }
}
