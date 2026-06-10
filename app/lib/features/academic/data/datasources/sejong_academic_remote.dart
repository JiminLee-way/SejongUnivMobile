import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';

class SejongAcademicRemote {
  SejongAcademicRemote({required this.client});
  final SejongApiClient client;

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
