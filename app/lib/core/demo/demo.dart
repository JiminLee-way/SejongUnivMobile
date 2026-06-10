// ─────────────────────────────────────────────────────────────────────────
// 데모/시연용 목업 레이어.
//
// 특정 내부 테스트 계정으로 로그인했을 때만 활성화된다. 화면에 보이는
// 프로필·시간표·친구·전자출결을 가짜 페르소나로 덮어 시연을 풍부하게
// 보이게 하되, **QR·NFC·열람실·토큰처럼 실제 백엔드가 필요한 동작은 실계정
// 값을 그대로 사용**한다(displayUser != currentUser 분리).
//
// 끄는 법: [kDemoStudentId]를 비우거나 [demoModeProvider]를 false 고정.
// 프로덕션 정식 출시 전에는 반드시 비활성화할 것.
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/domain/entities/sejong_user.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/data/datasources/mock_timetable.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_data.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_lecture.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_attend_record.dart';

/// 데모 페르소나가 켜지는 실계정 학번. 빈 문자열이면 데모 OFF.
/// 프로덕션 출시본은 반드시 빈 문자열(데모 OFF) — 실사용자는 본인 실데이터를 본다.
const String kDemoStudentId = '';

/// 학생증에 표시할 마스코트 사진 에셋.
const String kDemoMascotAsset = 'assets/images/demo_avatar.png';

/// 현재 로그인한 실계정이 데모 대상인지.
final demoModeProvider = Provider<bool>((ref) {
  if (kDemoStudentId.isEmpty) return false;
  return ref.watch(currentUserProvider)?.userId == kDemoStudentId;
});

/// 화면 "표시 전용" 사용자. 데모면 가짜 사용자로 마스킹, 아니면 실 사용자 그대로.
/// QR/NFC/열람실/온보딩은 이걸 쓰지 말고 [currentUserProvider]를 그대로 쓸 것.
final displayUserProvider = Provider<SejongUser?>((ref) {
  final real = ref.watch(currentUserProvider);
  if (real == null) return null;
  return ref.watch(demoModeProvider) ? demoDisplayUser(real) : real;
});

/// 데모 표시 프로필 — 식별자/학과/이름만 가짜, cardNo·roles 등 실값은 보존.
SejongUser demoDisplayUser(SejongUser real) => SejongUser(
  userId: '25777777',
  username: '데모학생',
  email: real.email,
  roles: real.roles,
  roleName: real.roleName,
  departmentName: '전지전능학과',
  organizationClassName: real.organizationClassName,
  birthDate: real.birthDate,
  studentYear: 3,
  cardNo: real.cardNo,
  cardNoIos: real.cardNoIos,
  cmsUserId: real.cmsUserId,
  roleCd: real.roleCd,
  statusName: '재학',
);

/// 데모 친구 목록 — 기존 mockFriends(f1~f12)를 재사용. id가 mockFriendTimetables
/// 키와 일치하므로 "함께 비는 시간" 비교가 그대로 동작한다.
List<Friend> demoFriends() => mockFriends;

/// 데모 시간표 — 2026-1학기에만 강의를 채우고 나머지 학기는 빈 시간표.
Timetable demoTimetable(Semester semester) {
  if (semester != Semester.spring2026) {
    return Timetable(semester: semester, courses: const []);
  }
  return const Timetable(
    semester: Semester.spring2026,
    courses: [
      Course(
        id: 'd1',
        code: 'OMN101',
        name: '전지전능학개론',
        professor: '신해린',
        location: '광개토관 101',
        palette: CoursePalette.crimson,
        credits: 3,
        times: [
          CourseTime(
            weekday: Weekday.mon,
            start: HMTime(9, 0),
            end: HMTime(10, 30),
          ),
          CourseTime(
            weekday: Weekday.wed,
            start: HMTime(9, 0),
            end: HMTime(10, 30),
          ),
        ],
      ),
      Course(
        id: 'd2',
        code: 'OMN210',
        name: '시공간 제어 실습',
        professor: '문도현',
        location: '광개토관 110',
        palette: CoursePalette.sky,
        credits: 3,
        times: [
          CourseTime(
            weekday: Weekday.tue,
            start: HMTime(13, 0),
            end: HMTime(14, 30),
          ),
          CourseTime(
            weekday: Weekday.thu,
            start: HMTime(13, 0),
            end: HMTime(14, 30),
          ),
        ],
      ),
      Course(
        id: 'd3',
        code: 'OMN320',
        name: '만물의 이론',
        professor: '한도연',
        location: '대양홀 D210',
        palette: CoursePalette.violet,
        credits: 3,
        times: [
          CourseTime(
            weekday: Weekday.mon,
            start: HMTime(13, 0),
            end: HMTime(15, 0),
          ),
        ],
      ),
      Course(
        id: 'd4',
        code: 'OMN350',
        name: '차원이동 설계',
        professor: '오세영',
        location: '충무관 305',
        palette: CoursePalette.amber,
        credits: 3,
        times: [
          CourseTime(
            weekday: Weekday.fri,
            start: HMTime(10, 0),
            end: HMTime(12, 0),
          ),
        ],
      ),
      Course(
        id: 'd5',
        code: 'GEN140',
        name: '우주 윤리와 책임',
        professor: '배수린',
        location: '율곡관 Y502',
        palette: CoursePalette.emerald,
        credits: 2,
        times: [
          CourseTime(
            weekday: Weekday.wed,
            start: HMTime(15, 0),
            end: HMTime(17, 0),
          ),
        ],
      ),
    ],
  );
}

/// 데모 전자출결 — 강의 3개 + 13주차치 출결(출석/지각/결석/조퇴 섞음).
UCheckData demoUCheckData() {
  return UCheckData(
    studentName: '데모학생',
    currentWeek: 13,
    totalWeeks: 16,
    lectures: [
      _demoLecture(
        lectureNo: 9001,
        name: '전지전능학개론',
        teacher: '신해린',
        dayKor: '월',
        dayWeek: '2',
        start: '0900',
        end: '1030',
        room: '광개토관101',
        // 13주차: 대부분 출석, 3주차 지각 1
        pattern: [
          '1',
          '1',
          '2',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
        ],
      ),
      _demoLecture(
        lectureNo: 9002,
        name: '시공간 제어 실습',
        teacher: '문도현',
        dayKor: '화',
        dayWeek: '3',
        start: '1300',
        end: '1430',
        room: '광개토관110',
        // 결석 1, 조퇴 1 섞음
        pattern: [
          '1',
          '1',
          '1',
          '3',
          '1',
          '1',
          '1',
          '1',
          '4',
          '1',
          '1',
          '1',
          '1',
        ],
      ),
      _demoLecture(
        lectureNo: 9003,
        name: '만물의 이론',
        teacher: '한도연',
        dayKor: '월',
        dayWeek: '2',
        start: '1300',
        end: '1500',
        room: '대양홀D210',
        // 개근
        pattern: [
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
          '1',
        ],
      ),
    ],
  );
}

LectureWithAttendance _demoLecture({
  required int lectureNo,
  required String name,
  required String teacher,
  required String dayKor,
  required String dayWeek,
  required String start,
  required String end,
  required String room,
  required List<String> pattern,
}) {
  // 3월 첫 주(월)을 기준으로 주차별 날짜를 만든다.
  final base = DateTime(2026, 3, 2); // 2026-03-02 (월)
  final records = <UCheckAttendRecord>[];
  var attendNo = lectureNo * 100;
  for (var i = 0; i < pattern.length; i++) {
    final week = i + 1;
    final d = base.add(Duration(days: 7 * i));
    final ymd =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final type = pattern[i];
    records.add(
      UCheckAttendRecord(
        lectureNo: lectureNo,
        lectureWeek: week,
        classNo: 1,
        checkType: '1',
        attendDate: type == '3' ? null : '$ymd${start}00',
        attendNo: attendNo++,
        lectureDate: ymd,
        startTime: start,
        endTime: end,
        roomCd: room,
        roomNm: room,
        attendType: type,
        studentNo: '25777777',
      ),
    );
  }
  final present = pattern.where((t) => t == '1').length;
  final late = pattern.where((t) => t == '2').length;
  final absent = pattern.where((t) => t == '3').length;
  final early = pattern.where((t) => t == '4').length;
  return LectureWithAttendance(
    lecture: UCheckLecture(
      lectureNo: lectureNo,
      curriculumNm: name,
      teacherNm: teacher,
      totalLectureTime:
          '$dayKor/${start.substring(0, 2)}:${start.substring(2)}~${end.substring(0, 2)}:${end.substring(2)}/$room',
      unitNo: 3,
      attendCnt: present,
      tardinessCnt: late,
      absenceCnt: absent,
      earlyLeaveCnt: early,
      lectureYear: 2026,
      lectureTerm: 1,
      studentNo: '25777777',
    ),
    records: records,
    classNo: 1,
    roomCd: room,
    roomNm: room,
    curWeek: 13,
    totalWeek: 16,
    startTime: '${start.substring(0, 2)}:${start.substring(2)}',
    endTime: '${end.substring(0, 2)}:${end.substring(2)}',
    dayWeek: dayWeek,
  );
}
