import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/sjpt/presentation/providers/sjpt_providers.dart';
import 'package:sejong_smart_campus/features/timetable/data/datasources/sejong_timetable_mapper.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/enrolled_course.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

/// 학기별 수강내역 요약(전체 학점 + 시간표 외 온라인/무수업일 강의).
///
/// 출처는 **SJPT 수강내역**(`SueReqLesnQ/doList.do`) — sjapp 시간표 그리드가
/// 수업시간 있는 강의만 보여줘 온라인·봉사 학점이 누락되는 걸 보완한다. SJPT
/// 세션(RUNNING_SEJONG) SSO가 선행돼야 하므로 [sjptInitProvider]를 먼저 await.
///
/// 실패(미로그인·SSO 실패·학기 매핑 없음)해도 시간표 자체엔 영향 없도록 호출부는
/// AsyncValue로 graceful 처리(요약 없으면 그리드 기반 학점으로 폴백).
final enrolledSummaryProvider = FutureProvider.autoDispose
    .family<EnrolledSummary, Semester>((ref, semester) async {
      final key = SejongTimetableMapper.toSejongKey(semester);
      if (key == null) {
        // ignore: avoid_print
        print('[ENROLL] no sjapp key for $semester');
        return EnrolledSummary.fromCourses(const []);
      }
      try {
        // RUNNING_SEJONG 확보(SSO). 시설예약과 동일 세션 공유.
        await ref.watch(sjptInitProvider.future);
        final client = await ref.watch(sjptClientProvider.future);
        final rows = await client.listEnrolledCourses(
          year: key.$1,
          smtCd: key.$2,
        );
        final courses = <EnrolledCourse>[];
        for (final r in rows) {
          final c = EnrolledCourse.fromSjptRow(r);
          if (c != null) courses.add(c);
        }
        // ignore: avoid_print
        print(
          '[ENROLL] ${key.$1}/${key.$2} rows=${rows.length} parsed=${courses.length}',
        );
        return EnrolledSummary.fromCourses(courses);
      } catch (e, st) {
        // ignore: avoid_print
        print('[ENROLL] FAILED ${key.$1}/${key.$2}: $e\n$st');
        rethrow;
      }
    });
