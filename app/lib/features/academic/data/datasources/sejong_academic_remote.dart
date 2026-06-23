import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';

class SejongAcademicRemote {
  SejongAcademicRemote({required this.client, Dio? webDio})
    : _webDio =
          webDio ??
          Dio(
            BaseOptions(
              baseUrl: _sejongWebBase,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              responseType: ResponseType.json,
              headers: const {
                'Accept': 'application/json, text/plain, */*',
                'Accept-Language': 'ko-KR,ko;q=0.9',
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/149.0 Mobile Safari/537.36',
              },
            ),
          );

  static const _fallbackSejongWebBase = 'https://www.sejong.ac.kr';
  static String get _sejongWebBase {
    final configured = ServiceUrls.sejongWeb.trim();
    if (configured.isEmpty) return _fallbackSejongWebBase;
    return configured.endsWith('/')
        ? configured.substring(0, configured.length - 1)
        : configured;
  }

  final SejongApiClient client;
  final Dio _webDio;

  Future<List<AcademicCalendarEvent>> fetchOfficialCalendarEvents({
    required DateTime start,
    required DateTime end,
    required AcademicCalendarCategory category,
  }) async {
    final res = await _webDio.get<dynamic>(
      '/kor/academics/academic-calendar.do',
      queryParameters: {
        'mode': 'getCalendarData',
        'start': _yyyyMmDd(start),
        'end': _yyyyMmDd(end),
        'collDiv': category.code,
      },
    );
    return parseOfficialCalendarResponse(res.data);
  }

  static List<AcademicCalendarEvent> parseOfficialCalendarResponse(
    Object? raw,
  ) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return const <AcademicCalendarEvent>[];
    final data = decoded['data'];
    if (data is! List) return const <AcademicCalendarEvent>[];
    return sortAcademicCalendarEvents(
      data
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .map(AcademicCalendarEvent.fromOfficialJson)
          .where((event) => event.title.isNotEmpty),
    );
  }

  static String _yyyyMmDd(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  Future<List<CalendarItem>> fetchDailyCalendar(String yyyyMmDd) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.academicCalendarDaily(yyyyMmDd),
    );
    return client.unwrap<List<CalendarItem>>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return ((m['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CalendarItem.fromJson)
          .toList();
    });
  }

  Future<List<CalendarItem>> fetchStudentDailyAll(String yyyyMmDd) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.studentDailyAll(yyyyMmDd),
    );
    return client.unwrap<List<CalendarItem>>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return ((m['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CalendarItem.fromJson)
          .toList();
    });
  }

  Future<GradeInquiry> fetchGrades() async {
    final res = await client.dio.get<dynamic>(SejongEndpoints.gradeInquiryAll);
    return client.unwrap<GradeInquiry>(
      res,
      (raw) => GradeInquiry.fromJson((raw as Map).cast<String, dynamic>()),
    );
  }

  /// 당해학기 성적. `data`는 특정 학기 상세와 같은 모양이다.
  Future<GradeSelectedSemester> fetchCurrentSemesterGrade() async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.gradeInquiryCurrent,
    );
    return client.unwrap<GradeSelectedSemester>(
      res,
      (raw) =>
          GradeSelectedSemester.fromJson((raw as Map).cast<String, dynamic>()),
    );
  }

  /// 특정 학기 성적 (과목 list 포함). 학기 chip 탭마다 호출.
  Future<GradeSelectedSemester> fetchGradeSemester(
    String year,
    String smtCd,
  ) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.gradeInquirySemester(year, smtCd),
    );
    return client.unwrap<GradeSelectedSemester>(
      res,
      (raw) =>
          GradeSelectedSemester.fromJson((raw as Map).cast<String, dynamic>()),
    );
  }

  /// 월간 marks — `data.scheduleDates: [1,5,9,...]` 형식.
  /// 공개 endpoint, 학과 무관 전체 학사일정 기준.
  Future<MonthlyMarks> fetchMonthlyMarks(int year, int month) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.academicCalendarMonthlyMarks(year, month),
    );
    return client.unwrap<MonthlyMarks>(
      res,
      (raw) => MonthlyMarks.fromJson((raw as Map).cast<String, dynamic>()),
    );
  }

  /// 학생용 월간 marks — 본인 학과(orgCode) 기준.
  /// orgCode 미지정 시 학부(20) default.
  Future<MonthlyMarks> fetchStudentMonthlyMarks(
    int year,
    int month, {
    String? orgCode,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.studentMonthlyMarks(year, month, orgCode: orgCode),
    );
    return client.unwrap<MonthlyMarks>(
      res,
      (raw) => MonthlyMarks.fromJson((raw as Map).cast<String, dynamic>()),
    );
  }

  Future<List<OrganizationType>> fetchOrganizationTypes() async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.academicOrganizationTypes,
    );
    return client.unwrap<List<OrganizationType>>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return ((m['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OrganizationType.fromJson)
          .toList();
    });
  }
}
