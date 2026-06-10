// UCheck **모바일** API DTOs — BLE 출석 체크 등 mobile.do 응답.
//
// 원본: `UCheckDtos.kt`의 `UCheckMobileInfo`/`UCheckMobileLecture`/관련 헬퍼들.
// 웹 API(UCheckLecture, UCheckResponse)와는 envelope/필드명 모두 다르다.

/// `mobileInfo.do` 응답 — 한 학기 강의 + 비콘 정보 일괄.
///
/// `weekdata`는 주(week) 단위 정적 정보, `daydata`는 오늘에 해당하는 dynamic
/// 비콘 할당이 들어있다. 같은 lectureNo+dayWeek에 대해 daydata가 더 신뢰
/// 가능하므로 [UCheckMobileInfoX.allLectures]가 머지할 때 daydata가 wins.
class UCheckMobileInfo {
  const UCheckMobileInfo({
    this.result = 0,
    this.weekdata = const <UCheckMobileLecture>[],
    this.daydata = const <UCheckMobileLecture>[],
    this.daydownyn = const <UCheckDayDownload>[],
    this.weekdownyn = const <UCheckWeekDownload>[],
    this.version,
  });

  /// 1=성공, 그 외 실패.
  final int result;

  /// 주 단위 강의/비콘 정보.
  final List<UCheckMobileLecture> weekdata;

  /// 오늘 일일 강의/비콘 정보 (교수 비콘 등 dynamic 항목 포함).
  final List<UCheckMobileLecture> daydata;

  /// 일일 다운로드 가능 여부.
  final List<UCheckDayDownload> daydownyn;

  /// 주간 다운로드 가능 여부.
  final List<UCheckWeekDownload> weekdownyn;

  /// 앱 버전/비콘 펌웨어 정보.
  final UCheckVersion? version;

  factory UCheckMobileInfo.fromJson(Map<String, dynamic> json) {
    return UCheckMobileInfo(
      result: (json['result'] as num?)?.toInt() ?? 0,
      weekdata: ((json['weekdata'] as List?) ?? const <dynamic>[])
          .map((e) => UCheckMobileLecture.fromJson(e as Map<String, dynamic>))
          .toList(),
      daydata: ((json['daydata'] as List?) ?? const <dynamic>[])
          .map((e) => UCheckMobileLecture.fromJson(e as Map<String, dynamic>))
          .toList(),
      daydownyn: ((json['daydownyn'] as List?) ?? const <dynamic>[])
          .map((e) => UCheckDayDownload.fromJson(e as Map<String, dynamic>))
          .toList(),
      weekdownyn: ((json['weekdownyn'] as List?) ?? const <dynamic>[])
          .map((e) => UCheckWeekDownload.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] == null
          ? null
          : UCheckVersion.fromJson(json['version'] as Map<String, dynamic>),
    );
  }
}

/// weekdata + daydata 머지 헬퍼.
extension UCheckMobileInfoX on UCheckMobileInfo {
  /// weekdata와 daydata를 머지하되 같은 `lectureNo-dayWeek` 키에 대해서는
  /// daydata가 wins (오늘의 dynamic 비콘 할당이 더 신뢰 가능).
  List<UCheckMobileLecture> get allLectures {
    if (weekdata.isEmpty) return daydata;
    if (daydata.isEmpty) return weekdata;
    final merged = <String, UCheckMobileLecture>{};
    for (final l in weekdata) {
      merged['${l.lectureNo}-${l.dayWeek}'] = l;
    }
    for (final l in daydata) {
      merged['${l.lectureNo}-${l.dayWeek}'] = l;
    }
    return merged.values.toList(growable: false);
  }
}

/// 모바일 API의 한 강의 (BLE 체크용 비콘 주소 포함).
///
/// `dayWeek`은 `"2"=월..\"7"=토` (UCheck 서버 규약, ISO와 다름).
class UCheckMobileLecture {
  const UCheckMobileLecture({
    this.apType = '',
    this.startTime = '',
    this.endTime = '',
    this.dayWeek = '',
    this.curriculumNm = '',
    this.curriculumCd = '',
    this.classNo = 0,
    this.teacherNm = '',
    this.roomCd = '',
    this.roomNm = '',
    this.lectureNo = 0,
    this.seq = 0,
    this.totalWeek = 0,
    this.curWeek = 0,
    this.attendUseYn = '',
    this.lectureType = 0,
    this.outCheckYn = '',
    this.autoAttendYn = '',
    this.attendSmin,
    this.attendEmin,
    this.outSmin,
    this.outEmin,
    this.laterMin,
    this.lectureDate,
    this.localName = const <String>[],
    this.beaconMacAddresses = const <String>[],
    this.teacherMacAddresses,
    this.stateCdAttend = 0,
    this.stateCdMiddle = 0,
    this.stateCdLeave = 0,
    this.stateCdCert = 0,
  });

  /// 비콘 AP 타입.
  final String apType;

  /// `"HHmm"` 강의 시작.
  final String startTime;

  /// `"HHmm"` 강의 종료.
  final String endTime;

  /// `"2"=월..\"7"=토` (UCheck 규약).
  final String dayWeek;

  /// 교과목명.
  final String curriculumNm;

  /// 교과목 코드.
  final String curriculumCd;

  /// 분반.
  final int classNo;

  /// 교수명.
  final String teacherNm;

  /// 강의실 코드.
  final String roomCd;

  /// 강의실 표시명.
  final String roomNm;

  /// 강의 PK.
  final int lectureNo;

  /// 순서.
  final int seq;

  /// 학기 총 주차.
  final int totalWeek;

  /// 현재 주차.
  final int curWeek;

  /// 출석 사용 여부 (`"Y"`/`"N"`).
  final String attendUseYn;

  /// 강의 타입.
  final int lectureType;

  /// 외부 체크 여부.
  final String outCheckYn;

  /// 자동 출석 여부.
  final String autoAttendYn;

  /// 출석 인정 시작 분(강의 시작 기준 ±).
  final int? attendSmin;

  /// 출석 인정 끝 분.
  final int? attendEmin;

  /// 조퇴 인정 시작 분.
  final int? outSmin;

  /// 조퇴 인정 끝 분.
  final int? outEmin;

  /// 지각 인정 분.
  final int? laterMin;

  /// 강의 일자 (`"yyyyMMdd"`).
  final String? lectureDate;

  /// BLE 비콘 local name 리스트.
  final List<String> localName;

  /// BLE 비콘 MAC 주소 리스트 (`b_maddr`).
  final List<String> beaconMacAddresses;

  /// 교수 비콘 MAC 주소 리스트 (`t_maddr`, daydata에서만 등장).
  final List<String>? teacherMacAddresses;

  /// 출석 상태 코드.
  final int stateCdAttend;

  /// 중간 상태 코드.
  final int stateCdMiddle;

  /// 조퇴 상태 코드.
  final int stateCdLeave;

  /// 인증 상태 코드.
  final int stateCdCert;

  factory UCheckMobileLecture.fromJson(Map<String, dynamic> json) {
    return UCheckMobileLecture(
      apType: json['ap_type'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      dayWeek: json['day_week'] as String? ?? '',
      curriculumNm: json['curriculum_nm'] as String? ?? '',
      curriculumCd: json['curriculum_cd'] as String? ?? '',
      classNo: (json['class_no'] as num?)?.toInt() ?? 0,
      teacherNm: json['teacher_nm'] as String? ?? '',
      roomCd: json['room_cd'] as String? ?? '',
      roomNm: json['room_nm'] as String? ?? '',
      lectureNo: (json['lecture_no'] as num?)?.toInt() ?? 0,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      totalWeek: (json['total_week'] as num?)?.toInt() ?? 0,
      curWeek: (json['cur_week'] as num?)?.toInt() ?? 0,
      attendUseYn: json['attend_use_yn'] as String? ?? '',
      lectureType: (json['lecture_type'] as num?)?.toInt() ?? 0,
      outCheckYn: json['out_check_yn'] as String? ?? '',
      autoAttendYn: json['auto_attend_yn'] as String? ?? '',
      attendSmin: (json['attend_smin'] as num?)?.toInt(),
      attendEmin: (json['attend_emin'] as num?)?.toInt(),
      outSmin: (json['out_smin'] as num?)?.toInt(),
      outEmin: (json['out_emin'] as num?)?.toInt(),
      laterMin: (json['later_min'] as num?)?.toInt(),
      lectureDate: json['lecture_date'] as String?,
      localName:
          (json['local_name'] as List?)?.cast<String>() ?? const <String>[],
      beaconMacAddresses:
          (json['b_maddr'] as List?)?.cast<String>() ?? const <String>[],
      teacherMacAddresses: (json['t_maddr'] as List?)?.cast<String>(),
      stateCdAttend: (json['state_cd_attend'] as num?)?.toInt() ?? 0,
      stateCdMiddle: (json['state_cd_middle'] as num?)?.toInt() ?? 0,
      stateCdLeave: (json['state_cd_leave'] as num?)?.toInt() ?? 0,
      stateCdCert: (json['state_cd_cert'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `attendCheck.do` 등의 모바일 출결 목록 응답.
class UCheckMobileAttendList {
  const UCheckMobileAttendList({
    this.result = 0,
    this.value = const <UCheckMobileAttend>[],
  });

  final int result;
  final List<UCheckMobileAttend> value;

  factory UCheckMobileAttendList.fromJson(Map<String, dynamic> json) {
    return UCheckMobileAttendList(
      result: (json['result'] as num?)?.toInt() ?? 0,
      value: ((json['value'] as List?) ?? const <dynamic>[])
          .map((e) => UCheckMobileAttend.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 모바일 API의 출결 한 건.
class UCheckMobileAttend {
  const UCheckMobileAttend({
    this.lectureNo = 0,
    this.lectureWeek = '',
    this.classNo = '',
    this.attendDate = '',
    this.attendTime = '',
    this.attendType = '',
    this.objectionStatus = '',
    this.exptStatus = '',
    this.leaveTime,
    this.limitRule,
  });

  /// 모바일 API는 lecture_no를 int 또는 numeric string으로 내려준다 — int로 통일.
  final int lectureNo;
  final String lectureWeek;
  final String classNo;
  final String attendDate;
  final String attendTime;

  /// `"1"=출석`, `"2"=지각`, `"3"=결석`, `"4"=조퇴`.
  final String attendType;

  /// 이의신청 상태.
  final String objectionStatus;

  /// 예외 사유 상태.
  final String exptStatus;

  /// 조퇴 시각.
  final String? leaveTime;

  /// 이의신청 기간 만료 플래그. `"true"`=기간 만료(불가) /
  /// `"false"`=가능 / `null`=알 수 없음
  /// (모바일 API가 같은 필드를 보내는지 확실치 않아 fallback로 [kDisputeWindowDays]
  /// 룰을 사용).
  final String? limitRule;

  factory UCheckMobileAttend.fromJson(Map<String, dynamic> json) {
    final rawLecture = json['lecture_no'];
    final int lecNo;
    if (rawLecture is num) {
      lecNo = rawLecture.toInt();
    } else if (rawLecture is String) {
      lecNo = int.tryParse(rawLecture) ?? 0;
    } else {
      lecNo = 0;
    }
    return UCheckMobileAttend(
      lectureNo: lecNo,
      lectureWeek: json['lecture_week'] as String? ?? '',
      classNo: json['class_no'] as String? ?? '',
      attendDate: json['attend_date'] as String? ?? '',
      attendTime: json['attend_time'] as String? ?? '',
      attendType: json['attend_type'] as String? ?? '',
      objectionStatus: json['objection_status'] as String? ?? '',
      exptStatus: json['expt_status'] as String? ?? '',
      leaveTime: json['leave_time'] as String?,
      limitRule: json['limit_rule'] as String?,
    );
  }

  bool get isAbsent => attendType == '3' || attendType == '4';

  /// 사용자가 이의신청을 **제출 완료**한 상태인가.
  ///
  /// 미신청 결석도 `objection_status="1"` 로 내려올 수 있어 가장 보수적으로
  /// **`"2"` 만** 제출/처리됨으로 인정하고 그 외는 모두 미신청 취급한다.
  bool get hasSubmittedObjection => objectionStatus == '2';

  /// `attend_date`(yyyyMMdd) 우선, 비었으면 `attend_time`의 앞 8자 파싱.
  DateTime? get attendDateAsDate {
    final s = attendDate.isNotEmpty
        ? attendDate
        : (attendTime.length >= 8 ? attendTime.substring(0, 8) : '');
    if (s.length < 8) return null;
    final y = int.tryParse(s.substring(0, 4));
    final m = int.tryParse(s.substring(4, 6));
    final d = int.tryParse(s.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// 이의신청 가능 기간 윈도우.
  ///
  /// 기간 정보 필드가 없으면 결석일로부터 **30일 이내**를 fallback 룰로 사용한다.
  ///
  /// 신청 가능 표시했더라도 서버가 거부할 수 있으므로 dispute 시트는 그대로
  /// 실패 핸들링을 유지한다.
  static const int kDisputeWindowDays = 30;

  bool isWithinDisputeWindow(DateTime now) {
    final d = attendDateAsDate;
    if (d == null) return false;
    return now.difference(d).inDays <= kDisputeWindowDays;
  }

  /// 결석 행의 이의신청 가능 여부 — 권위 신호 우선, 없으면 fallback 룰.
  ///
  /// 우선순위:
  ///  1. `limit_rule == "true"` → 만료 (불가)
  ///  2. `limit_rule == "false"` → 가능
  ///  3. `limit_rule == null` (모바일이 안 보내는 경우) → [kDisputeWindowDays] 룰
  bool canSubmitObjection(DateTime now) {
    final rule = limitRule;
    if (rule == 'true') return false;
    if (rule == 'false') return true;
    return isWithinDisputeWindow(now);
  }
}

/// 학기 선택 응답 (`getYearterm.do` 등).
class UCheckMobileSemester {
  const UCheckMobileSemester({
    this.result = 0,
    this.value = const <UCheckYearterm>[],
  });

  final int result;
  final List<UCheckYearterm> value;

  factory UCheckMobileSemester.fromJson(Map<String, dynamic> json) {
    return UCheckMobileSemester(
      result: (json['result'] as num?)?.toInt() ?? 0,
      value: ((json['value'] as List?) ?? const <dynamic>[])
          .map((e) => UCheckYearterm.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 학년도/학기 한 건. 원본 Kotlin의 풍부한 필드(beginDate/totalWeek 등)도 보존.
class UCheckYearterm {
  const UCheckYearterm({
    this.lectureYear = 0,
    this.lectureTerm = 0,
    this.beginDate = '',
    this.startDate = '',
    this.endDate = '',
    this.totalWeek = 0,
    this.displayYn = '',
  });

  final int lectureYear;
  final int lectureTerm;
  final String beginDate;
  final String startDate;
  final String endDate;
  final int totalWeek;
  final String displayYn;

  factory UCheckYearterm.fromJson(Map<String, dynamic> json) {
    return UCheckYearterm(
      lectureYear: (json['lecture_year'] as num?)?.toInt() ?? 0,
      lectureTerm: (json['lecture_term'] as num?)?.toInt() ?? 0,
      beginDate: json['begin_date'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      totalWeek: (json['total_week'] as num?)?.toInt() ?? 0,
      displayYn: json['display_yn'] as String? ?? '',
    );
  }
}

/// 일일 다운로드 상태.
class UCheckDayDownload {
  const UCheckDayDownload({this.dayDownloadYn = '', this.currTime = ''});

  final String dayDownloadYn;
  final String currTime;

  factory UCheckDayDownload.fromJson(Map<String, dynamic> json) {
    return UCheckDayDownload(
      dayDownloadYn: json['day_download_yn'] as String? ?? '',
      currTime: json['curr_time'] as String? ?? '',
    );
  }
}

/// 주간 다운로드 상태.
///
/// 원본 Kotlin의 `download`는 String이지만 spec은 int — 두 형태 모두 수용.
class UCheckWeekDownload {
  const UCheckWeekDownload({
    this.curWeek = 0,
    this.totalWeek = 0,
    this.download = 0,
  });

  final int curWeek;
  final int totalWeek;
  final int download;

  factory UCheckWeekDownload.fromJson(Map<String, dynamic> json) {
    final raw = json['download'];
    final int dl;
    if (raw is num) {
      dl = raw.toInt();
    } else if (raw is String) {
      dl = int.tryParse(raw) ?? 0;
    } else {
      dl = 0;
    }
    return UCheckWeekDownload(
      curWeek: (json['cur_week'] as num?)?.toInt() ?? 0,
      totalWeek: (json['total_week'] as num?)?.toInt() ?? 0,
      download: dl,
    );
  }
}

/// 앱/비콘 버전 정보.
class UCheckVersion {
  const UCheckVersion({
    this.key = '',
    this.essential,
    this.latest,
    this.mBeacon,
  });

  /// 버전 key.
  final String key;

  /// 필수 버전 (이 미만은 강제 업데이트).
  final VersionInfo? essential;

  /// 최신 버전 (옵션 업데이트 안내).
  final VersionInfo? latest;

  /// 페어링된 BLE 비콘 목록.
  final List<MBeacon>? mBeacon;

  factory UCheckVersion.fromJson(Map<String, dynamic> json) {
    final essRaw = json['essential'];
    final latRaw = json['latest'];
    return UCheckVersion(
      key: json['key'] as String? ?? '',
      essential: essRaw is Map<String, dynamic>
          ? VersionInfo.fromJson(essRaw)
          : (essRaw is String ? VersionInfo(version: essRaw) : null),
      latest: latRaw is Map<String, dynamic>
          ? VersionInfo.fromJson(latRaw)
          : (latRaw is String ? VersionInfo(version: latRaw) : null),
      mBeacon: (json['m_beacon'] as List?)
          ?.map((e) => MBeacon.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 단순 버전 wrapper — `essential`/`latest` 양쪽에 사용.
class VersionInfo {
  const VersionInfo({this.version = ''});

  final String version;

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(version: json['version'] as String? ?? '');
  }
}

/// 페어링된 BLE 비콘.
class MBeacon {
  const MBeacon({
    this.apType = '',
    this.localAddress = '',
    this.macAddress = '',
  });

  final String apType;
  final String localAddress;
  final String macAddress;

  factory MBeacon.fromJson(Map<String, dynamic> json) {
    return MBeacon(
      apType: json['ap_type'] as String? ?? '',
      localAddress: json['local_address'] as String? ?? '',
      macAddress: json['mac_address'] as String? ?? '',
    );
  }
}
