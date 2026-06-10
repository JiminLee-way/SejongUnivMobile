import 'package:sejong_smart_campus/features/community/domain/entities/community_models.dart';

DateTime _ago(Duration d) => DateTime.now().subtract(d);

final mockNotices = <NoticeItem>[
  NoticeItem(
    id: 'n01',
    category: NoticeCategory.academic,
    title: '2026학년도 1학기 수강신청 일정 안내',
    publisher: '학사지원팀',
    publishedAt: _ago(const Duration(hours: 3)),
    isPinned: true,
    hasAttachment: true,
    viewCount: 4821,
  ),
  NoticeItem(
    id: 'n02',
    category: NoticeCategory.scholarship,
    title: '2026-1학기 국가장학금 2차 신청 안내 (~5/30)',
    publisher: '장학복지팀',
    publishedAt: _ago(const Duration(hours: 7)),
    isPinned: true,
    hasAttachment: true,
    viewCount: 3210,
  ),
  NoticeItem(
    id: 'n03',
    category: NoticeCategory.career,
    title: '[채용설명회] 네이버 클라우드 신입공채 캠퍼스 리크루팅',
    publisher: '취업지원처',
    publishedAt: _ago(const Duration(hours: 11)),
    hasAttachment: false,
    viewCount: 1532,
  ),
  NoticeItem(
    id: 'n04',
    category: NoticeCategory.exchangeKr,
    title: '2026-2학기 교환학생 모집 (미국·유럽·동남아 28개교)',
    publisher: '국제교류원',
    publishedAt: _ago(const Duration(days: 1)),
    hasAttachment: true,
    viewCount: 2901,
  ),
  NoticeItem(
    id: 'n05',
    category: NoticeCategory.exchangeEn,
    title: 'Application Open — 2026 Fall Inbound Exchange Program',
    publisher: 'Office of International Affairs',
    publishedAt: _ago(const Duration(days: 1, hours: 4)),
    hasAttachment: true,
    viewCount: 612,
  ),
  NoticeItem(
    id: 'n06',
    category: NoticeCategory.general,
    title: '5/25(월) 전산 시스템 정기 점검 안내 (00:00~04:00)',
    publisher: '정보화지원팀',
    publishedAt: _ago(const Duration(days: 2)),
    viewCount: 854,
  ),
  NoticeItem(
    id: 'n07',
    category: NoticeCategory.admission,
    title: '2027학년도 수시모집 요강 사전 안내',
    publisher: '입학처',
    publishedAt: _ago(const Duration(days: 2, hours: 6)),
    hasAttachment: true,
    viewCount: 1102,
  ),
  NoticeItem(
    id: 'n08',
    category: NoticeCategory.academic,
    title: '계절학기 수업 운영 계획 및 신청 안내',
    publisher: '학사지원팀',
    publishedAt: _ago(const Duration(days: 3)),
    hasAttachment: false,
    viewCount: 2018,
  ),
  NoticeItem(
    id: 'n09',
    category: NoticeCategory.career,
    title: 'AI/데이터 직무 모의 면접 신청 (참여자 50명 한정)',
    publisher: '취업지원처',
    publishedAt: _ago(const Duration(days: 3, hours: 8)),
    viewCount: 743,
  ),
  NoticeItem(
    id: 'n10',
    category: NoticeCategory.scholarship,
    title: '근로장학생 모집 — 학기 중 도서관/실험실 보조',
    publisher: '장학복지팀',
    publishedAt: _ago(const Duration(days: 4)),
    hasAttachment: true,
    viewCount: 1287,
  ),
];

final mockNews = <NewsItem>[
  NewsItem(
    id: 'news01',
    title: '세종대 AI융합대학, 글로벌 AI 학회 NeurIPS 2026에 논문 8편 채택',
    summary:
        '인공지능데이터사이언스학과·컴퓨터공학과 연구진의 성과 — '
        'LLM 추론 효율화·멀티모달 정합·강화학습 안정성 등 다양한 주제.',
    publishedAt: _ago(const Duration(hours: 4)),
    thumbnailSeed: 0xA73B1F,
    tag: 'AI연구',
  ),
  NewsItem(
    id: 'news02',
    title: '광개토관 리모델링 완료 — 학습공간 + 학생 라운지 새단장',
    summary:
        '1·2층은 24시간 개방형 스터디 라운지, 3·4층은 그룹 토의실 12개, '
        '지하 1층은 IoT 실험실로 재편.',
    publishedAt: _ago(const Duration(hours: 22)),
    thumbnailSeed: 0x6B5BFF,
    tag: '캠퍼스',
  ),
  NewsItem(
    id: 'news03',
    title: '세종대-카카오 산학협력 MOU — 클라우드·AI 인프라 공동 활용',
    summary:
        '학생 인턴십 정원 30명, 공동 연구비 5억원 규모. '
        '내년 1학기부터 산학공동 강좌 개설 예정.',
    publishedAt: _ago(const Duration(days: 1, hours: 2)),
    thumbnailSeed: 0xF5C400,
    tag: '산학협력',
  ),
  NewsItem(
    id: 'news04',
    title: '봄 축제 "대양가요제" 5/30 개최 — 인기 아티스트 라인업 공개',
    summary:
        '본 무대 18:00 개막. 헤드라이너 NewJeans, 잔나비, 윤하 출연 확정. '
        '캠퍼스 곳곳 푸드트럭과 학생 부스 운영.',
    publishedAt: _ago(const Duration(days: 1, hours: 11)),
    thumbnailSeed: 0xE91E63,
    tag: '학생행사',
  ),
  NewsItem(
    id: 'news05',
    title: '세종대 농구부, 대학농구리그 3년 연속 4강 진출',
    summary:
        '연장 접전 끝 한양대를 78-74로 꺾고 4강행. '
        '준결승은 5/28(수) 잠실 학생체육관.',
    publishedAt: _ago(const Duration(days: 2, hours: 3)),
    thumbnailSeed: 0x0CA886,
    tag: '스포츠',
  ),
];

final mockBoardPosts = <BoardPost>[
  BoardPost(
    id: 'p01',
    board: Board.free,
    title: '광개토관 새 라운지 진짜 좋다',
    preview:
        '오늘 처음 가봤는데 의자가 너무 편함. 콘센트도 자리마다 있고 '
        '소음도 적당하고 6시간째 코딩 중인데 안 피곤한 거 처음.',
    author: '익명의 멍멍이',
    postedAt: _ago(const Duration(hours: 1)),
    likeCount: 142,
    commentCount: 37,
    isHot: true,
  ),
  BoardPost(
    id: 'p02',
    board: Board.career,
    title: '카카오 인턴 1차 면접 후기 (AI 데이터 직무)',
    preview:
        '오늘 오전에 1차 보고 왔습니다. 기술면접 30분 + 인성 15분. '
        '코테 풀이 과정 다시 설명하기 + 프로젝트 디테일 위주로...',
    author: '23학번_졸업예정',
    postedAt: _ago(const Duration(hours: 3)),
    likeCount: 98,
    commentCount: 24,
    isHot: true,
  ),
  BoardPost(
    id: 'p03',
    board: Board.anonymous,
    title: '시험 망쳤는데 재수강 vs F학점 어느게 나아요',
    preview:
        '재수강하면 학점 올라가긴 하는데 그 한 학기 시간이 너무 아까워서요. '
        'D+이고 졸업학점에는 영향 없을 거 같은데...',
    author: '익명',
    postedAt: _ago(const Duration(hours: 5)),
    likeCount: 64,
    commentCount: 89,
    isHot: true,
    isAnonymous: true,
  ),
  BoardPost(
    id: 'p04',
    board: Board.market,
    title: '[판매] 자료구조 교재 거의 새거 8천원',
    preview:
        '한 학기 두세번 펴봤습니다. 필기 거의 없어요. '
        '광개토관 근처에서 직거래 가능. 입금자명으로 쪽지 주세요.',
    author: '컴공_25',
    postedAt: _ago(const Duration(hours: 6)),
    likeCount: 12,
    commentCount: 5,
  ),
  BoardPost(
    id: 'p05',
    board: Board.food,
    title: '군자역 근처에 새로 생긴 마라탕 가성비 굿',
    preview:
        '7천원에 토핑 6개 골라먹는 마라탕 + 꿔바로우 미니. '
        '면 추가도 무료. 사진 첨부.',
    author: '익명의 호랑이',
    postedAt: _ago(const Duration(hours: 9)),
    likeCount: 56,
    commentCount: 18,
  ),
  BoardPost(
    id: 'p06',
    board: Board.housing,
    title: '광나루역 5분거리 풀옵션 원룸 보증금 1000/55',
    preview:
        '내년 3월에 졸업해서 양도합니다. 14평 풀옵션이고 채광 좋아요. '
        '관심 있으신 분 댓글이나 쪽지 부탁드려요.',
    author: '익명의 부엉이',
    postedAt: _ago(const Duration(hours: 13)),
    likeCount: 21,
    commentCount: 8,
  ),
  BoardPost(
    id: 'p07',
    board: Board.qna,
    title: '학과 사무실은 어디로 가야하나요',
    preview:
        '복학 처리하러 가야하는데 학사정보시스템에서는 위치가 안 보여서요. '
        '인공지능데이터사이언스학과 사무실 위치 아시는 분?',
    author: '신입생_25',
    postedAt: _ago(const Duration(hours: 19)),
    likeCount: 4,
    commentCount: 11,
  ),
];
