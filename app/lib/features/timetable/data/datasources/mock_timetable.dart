import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

/// 시안용 학기별 mock 시간표.
///
/// 정규 학기(1·2학기)는 5~6과목, 계절학기는 1~2과목.
/// 9:00–19:00 안에서 다양한 시간대를 커버하도록 의도적으로 분산 배치.

const _spring2025 = Timetable(
  semester: Semester.spring2025,
  courses: [
    Course(
      id: 'cse301',
      code: 'CSE301',
      name: '운영체제',
      professor: '김지훈',
      location: '광개토관 S202',
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
      id: 'cse311',
      code: 'CSE311',
      name: '데이터베이스',
      professor: '박서영',
      location: '광개토관 S401',
      palette: CoursePalette.sky,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
      ],
    ),
    Course(
      id: 'mth201',
      code: 'MTH201',
      name: '선형대수학',
      professor: '이수민',
      location: '진리관 R104',
      palette: CoursePalette.violet,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(13, 0),
          end: HMTime(14, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(13, 0),
          end: HMTime(14, 30),
        ),
      ],
    ),
    Course(
      id: 'eng105',
      code: 'ENG105',
      name: 'College English II',
      professor: 'Sarah Park',
      location: '율곡관 Y502',
      palette: CoursePalette.emerald,
      credits: 2,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(15, 0),
          end: HMTime(16, 30),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(15, 0),
          end: HMTime(16, 30),
        ),
      ],
    ),
    Course(
      id: 'cse350',
      code: 'CSE350',
      name: '알고리즘',
      professor: '최우석',
      location: '광개토관 S305',
      palette: CoursePalette.amber,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.fri,
          start: HMTime(9, 30),
          end: HMTime(12, 0),
        ),
      ],
    ),
    Course(
      id: 'hum201',
      code: 'HUM201',
      name: '현대사회와 윤리',
      professor: '한지수',
      location: '대양홀 D210',
      palette: CoursePalette.teal,
      credits: 2,
      times: [
        CourseTime(
          weekday: Weekday.fri,
          start: HMTime(14, 0),
          end: HMTime(16, 0),
        ),
      ],
    ),
  ],
);

const _summer2025 = Timetable(
  semester: Semester.summer2025,
  courses: [
    Course(
      id: 'cse291',
      code: 'CSE291',
      name: '자료구조 (계절)',
      professor: '윤도현',
      location: '광개토관 S203',
      palette: CoursePalette.rose,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(10, 0),
          end: HMTime(13, 0),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(10, 0),
          end: HMTime(13, 0),
        ),
      ],
    ),
  ],
);

const _fall2025 = Timetable(
  semester: Semester.fall2025,
  courses: [
    Course(
      id: 'cse401',
      code: 'CSE401',
      name: '컴퓨터네트워크',
      professor: '강민서',
      location: '광개토관 S402',
      palette: CoursePalette.indigo,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(11, 0),
          end: HMTime(12, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(11, 0),
          end: HMTime(12, 30),
        ),
      ],
    ),
    Course(
      id: 'cse421',
      code: 'CSE421',
      name: '소프트웨어공학',
      professor: '서지원',
      location: '광개토관 S501',
      palette: CoursePalette.crimson,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(9, 0),
          end: HMTime(10, 30),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(9, 0),
          end: HMTime(10, 30),
        ),
      ],
    ),
    Course(
      id: 'cse451',
      code: 'CSE451',
      name: '인공지능',
      professor: '신유진',
      location: '광개토관 S307',
      palette: CoursePalette.violet,
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
      id: 'cse499',
      code: 'CSE499',
      name: '캡스톤 디자인',
      professor: '오태경',
      location: '광개토관 S110',
      palette: CoursePalette.amber,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.fri,
          start: HMTime(13, 0),
          end: HMTime(17, 0),
        ),
      ],
    ),
    Course(
      id: 'gen102',
      code: 'GEN102',
      name: '심리학의 이해',
      professor: '문혜린',
      location: '대양홀 D305',
      palette: CoursePalette.teal,
      credits: 2,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(15, 0),
          end: HMTime(17, 0),
        ),
      ],
    ),
  ],
);

const _winter2025 = Timetable(
  semester: Semester.winter2025,
  courses: [
    Course(
      id: 'mth250',
      code: 'MTH250',
      name: '확률과 통계 (계절)',
      professor: '정유리',
      location: '진리관 R102',
      palette: CoursePalette.sky,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(13, 0),
          end: HMTime(16, 0),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(13, 0),
          end: HMTime(16, 0),
        ),
      ],
    ),
  ],
);

const _spring2026 = Timetable(semester: Semester.spring2026, courses: []);

const mockTimetables = <Semester, Timetable>{
  Semester.spring2025: _spring2025,
  Semester.summer2025: _summer2025,
  Semester.fall2025: _fall2025,
  Semester.winter2025: _winter2025,
  Semester.spring2026: _spring2026,
};

const mockFriends = <Friend>[
  Friend(
    id: 'f1',
    name: '김민지',
    major: '컴퓨터공학',
    status: FriendStatus.inClass,
    currentActivity: '운영체제 · S202',
    nextSlot: '다음: 13:00 선형대수학',
    avatarSeed: 1,
  ),
  Friend(
    id: 'f2',
    name: '박서준',
    major: '경영학',
    status: FriendStatus.studying,
    currentActivity: '학술정보원 4F',
    nextSlot: '다음: 15:00 마케팅원론',
    avatarSeed: 2,
  ),
  Friend(
    id: 'f3',
    name: '이하늘',
    major: '디자인이노베이션',
    status: FriendStatus.free,
    currentActivity: '센트럴파크',
    nextSlot: '다음: 14:30 UX기초',
    avatarSeed: 3,
  ),
  Friend(
    id: 'f4',
    name: '최도윤',
    major: '소프트웨어',
    status: FriendStatus.inClass,
    currentActivity: '데이터베이스 · S401',
    nextSlot: '다음: 14:00 자유 시간',
    avatarSeed: 4,
  ),
  Friend(
    id: 'f5',
    name: '정유나',
    major: '국제학',
    status: FriendStatus.offline,
    currentActivity: '외부 — 인턴',
    nextSlot: null,
    avatarSeed: 5,
  ),
  Friend(
    id: 'f6',
    name: '한지호',
    major: '전자정보통신',
    status: FriendStatus.free,
    currentActivity: '학생회관 카페',
    nextSlot: '다음: 16:00 회로이론',
    avatarSeed: 6,
  ),
  Friend(
    id: 'f7',
    name: '강유진',
    major: '바이오융합',
    status: FriendStatus.studying,
    currentActivity: '도서관 2F 열람실',
    nextSlot: '다음: 17:00 분자생물학',
    avatarSeed: 7,
  ),
  Friend(
    id: 'f8',
    name: '서재현',
    major: '컴퓨터공학',
    status: FriendStatus.inClass,
    currentActivity: '알고리즘 · S305',
    nextSlot: '다음: 14:00 자유 시간',
    avatarSeed: 8,
  ),
  Friend(
    id: 'f9',
    name: '오수빈',
    major: '심리학',
    status: FriendStatus.free,
    currentActivity: '학생회관',
    nextSlot: '다음: 15:30 상담심리학',
    avatarSeed: 9,
  ),
  Friend(
    id: 'f10',
    name: '윤하린',
    major: '미디어커뮤니케이션',
    status: FriendStatus.offline,
    currentActivity: '귀가',
    nextSlot: null,
    avatarSeed: 10,
  ),
  Friend(
    id: 'f11',
    name: '임도현',
    major: '소프트웨어',
    status: FriendStatus.studying,
    currentActivity: '소프트웨어융합대학 랩',
    nextSlot: '다음: 18:00 캡스톤 미팅',
    avatarSeed: 11,
  ),
  Friend(
    id: 'f12',
    name: '배소율',
    major: '국제경영',
    status: FriendStatus.inClass,
    currentActivity: 'Global Business · Y502',
    nextSlot: '다음: 13:00 자유 시간',
    avatarSeed: 12,
  ),
];

/// 친구별 시간표 mock — 친구 시간표 뷰어 / 공강 비교용.
/// 현재 학기(2025-1) 기준. 일부 강의는 본인과 겹치도록 의도적으로 매핑해
/// 친구 시간표 뷰어의 "함께 듣는 강의" ⭐ 배지가 보이도록 함.
const mockFriendTimetables = <String, List<Course>>{
  'f1': [
    Course(
      id: 'f1_c1',
      code: 'CSE301',
      name: '운영체제',
      professor: '김지훈',
      location: '광개토관 S202',
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
      id: 'f1_c2',
      code: 'MTH201',
      name: '선형대수학',
      professor: '이수민',
      location: '진리관 R104',
      palette: CoursePalette.violet,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(13, 0),
          end: HMTime(14, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(13, 0),
          end: HMTime(14, 30),
        ),
      ],
    ),
    Course(
      id: 'f1_c3',
      code: 'CSE220',
      name: '컴퓨터구조',
      professor: '나경준',
      location: '광개토관 S303',
      palette: CoursePalette.sky,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
      ],
    ),
  ],
  'f2': [
    Course(
      id: 'f2_c1',
      code: 'MGT101',
      name: '경영학원론',
      professor: '서지은',
      location: '율곡관 Y302',
      palette: CoursePalette.indigo,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
      ],
    ),
    Course(
      id: 'f2_c2',
      code: 'MGT220',
      name: '마케팅원론',
      professor: '한성호',
      location: '율곡관 Y401',
      palette: CoursePalette.amber,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(13, 0),
          end: HMTime(15, 0),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(13, 0),
          end: HMTime(15, 0),
        ),
      ],
    ),
    Course(
      id: 'f2_c3',
      code: 'ECN101',
      name: '미시경제학',
      professor: '오현우',
      location: '율곡관 Y201',
      palette: CoursePalette.emerald,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.fri,
          start: HMTime(10, 0),
          end: HMTime(12, 30),
        ),
      ],
    ),
  ],
  'f3': [
    Course(
      id: 'f3_c1',
      code: 'DSN101',
      name: 'UX기초',
      professor: '백은수',
      location: '학생회관 D102',
      palette: CoursePalette.rose,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(14, 30),
          end: HMTime(16, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(14, 30),
          end: HMTime(16, 30),
        ),
      ],
    ),
    Course(
      id: 'f3_c2',
      code: 'ENG105',
      name: 'College English II',
      professor: 'Sarah Park',
      location: '율곡관 Y502',
      palette: CoursePalette.emerald,
      credits: 2,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(15, 0),
          end: HMTime(16, 30),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(15, 0),
          end: HMTime(16, 30),
        ),
      ],
    ),
  ],
  'f4': [
    Course(
      id: 'f4_c1',
      code: 'CSE311',
      name: '데이터베이스',
      professor: '박서영',
      location: '광개토관 S401',
      palette: CoursePalette.sky,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(10, 30),
          end: HMTime(12, 0),
        ),
      ],
    ),
    Course(
      id: 'f4_c2',
      code: 'CSE350',
      name: '알고리즘',
      professor: '최우석',
      location: '광개토관 S305',
      palette: CoursePalette.amber,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.fri,
          start: HMTime(9, 30),
          end: HMTime(12, 0),
        ),
      ],
    ),
    Course(
      id: 'f4_c3',
      code: 'CSE410',
      name: '컴파일러',
      professor: '강현지',
      location: '광개토관 S210',
      palette: CoursePalette.teal,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(15, 0),
          end: HMTime(16, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(15, 0),
          end: HMTime(16, 30),
        ),
      ],
    ),
  ],
  'f5': [
    Course(
      id: 'f5_c1',
      code: 'INT201',
      name: '국제관계론',
      professor: '윤지영',
      location: '광개토관 G301',
      palette: CoursePalette.violet,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(9, 0),
          end: HMTime(10, 30),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(9, 0),
          end: HMTime(10, 30),
        ),
      ],
    ),
  ],
  'f6': [
    Course(
      id: 'f6_c1',
      code: 'ECE201',
      name: '회로이론',
      professor: '나경준',
      location: '광개토관 S502',
      palette: CoursePalette.indigo,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(16, 0),
          end: HMTime(17, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(16, 0),
          end: HMTime(17, 30),
        ),
      ],
    ),
    Course(
      id: 'f6_c2',
      code: 'MTH201',
      name: '선형대수학',
      professor: '이수민',
      location: '진리관 R104',
      palette: CoursePalette.violet,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(13, 0),
          end: HMTime(14, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(13, 0),
          end: HMTime(14, 30),
        ),
      ],
    ),
  ],
  'f7': [
    Course(
      id: 'f7_c1',
      code: 'BIO301',
      name: '분자생물학',
      professor: '김라온',
      location: '진리관 R305',
      palette: CoursePalette.emerald,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(17, 0),
          end: HMTime(18, 30),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(17, 0),
          end: HMTime(18, 30),
        ),
      ],
    ),
  ],
  'f8': [
    Course(
      id: 'f8_c1',
      code: 'CSE350',
      name: '알고리즘',
      professor: '최우석',
      location: '광개토관 S305',
      palette: CoursePalette.amber,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.fri,
          start: HMTime(9, 30),
          end: HMTime(12, 0),
        ),
      ],
    ),
    Course(
      id: 'f8_c2',
      code: 'CSE301',
      name: '운영체제',
      professor: '김지훈',
      location: '광개토관 S202',
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
  ],
  'f9': [
    Course(
      id: 'f9_c1',
      code: 'PSY210',
      name: '상담심리학',
      professor: '문혜린',
      location: '대양홀 D210',
      palette: CoursePalette.teal,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.tue,
          start: HMTime(15, 30),
          end: HMTime(17, 0),
        ),
        CourseTime(
          weekday: Weekday.thu,
          start: HMTime(15, 30),
          end: HMTime(17, 0),
        ),
      ],
    ),
  ],
  'f10': [],
  'f11': [
    Course(
      id: 'f11_c1',
      code: 'CSE499',
      name: '캡스톤 디자인',
      professor: '오태경',
      location: '광개토관 S110',
      palette: CoursePalette.amber,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.fri,
          start: HMTime(13, 0),
          end: HMTime(17, 0),
        ),
      ],
    ),
  ],
  'f12': [
    Course(
      id: 'f12_c1',
      code: 'GBA201',
      name: 'Global Business',
      professor: 'David Kim',
      location: '율곡관 Y502',
      palette: CoursePalette.sky,
      credits: 3,
      times: [
        CourseTime(
          weekday: Weekday.mon,
          start: HMTime(11, 0),
          end: HMTime(12, 30),
        ),
        CourseTime(
          weekday: Weekday.wed,
          start: HMTime(11, 0),
          end: HMTime(12, 30),
        ),
      ],
    ),
  ],
};

/// 친구 초대 검색용 시안 데이터.
///
/// 절반은 가입자(registered) — [친구 요청] CTA, 절반은 미가입(unregistered) —
/// [초대 링크] CTA로 매핑된다. 모든 학번은 이미 마스킹된 상태.
const mockInviteCandidates = <InviteCandidate>[
  InviteCandidate(
    id: 'c1',
    name: '윤지아',
    studentIdMasked: '2021****7',
    major: '소프트웨어학과',
    kind: InviteCandidateKind.registered,
    avatarSeed: 13,
  ),
  InviteCandidate(
    id: 'c2',
    name: '권태현',
    studentIdMasked: '2020****2',
    major: '컴퓨터공학과',
    kind: InviteCandidateKind.registered,
    avatarSeed: 14,
  ),
  InviteCandidate(
    id: 'c3',
    name: '장하윤',
    studentIdMasked: '2022****0',
    major: '국제학부',
    kind: InviteCandidateKind.registered,
    avatarSeed: 15,
  ),
  InviteCandidate(
    id: 'c4',
    name: '신유나',
    studentIdMasked: '2019****5',
    major: '경영학부',
    kind: InviteCandidateKind.unregistered,
    avatarSeed: 16,
  ),
  InviteCandidate(
    id: 'c5',
    name: '조민서',
    studentIdMasked: '2023****9',
    major: '디자인이노베이션학과',
    kind: InviteCandidateKind.unregistered,
    avatarSeed: 17,
  ),
  InviteCandidate(
    id: 'c6',
    name: '안도윤',
    studentIdMasked: '2018****4',
    major: '전자정보통신공학과',
    kind: InviteCandidateKind.unregistered,
    avatarSeed: 18,
  ),
  InviteCandidate(
    id: 'c7',
    name: '김민서',
    studentIdMasked: '2022****1',
    major: '심리학과',
    kind: InviteCandidateKind.registered,
    avatarSeed: 19,
  ),
  InviteCandidate(
    id: 'c8',
    name: '박지호',
    studentIdMasked: '2021****6',
    major: '데이터사이언스학과',
    kind: InviteCandidateKind.unregistered,
    avatarSeed: 20,
  ),
];
