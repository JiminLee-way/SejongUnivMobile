/// 강의실 예약 도메인 모델.
library;

/// 강의실 목록 항목 (doListFacilityMst.do).
class SjptFacility {
  const SjptFacility({
    required this.roomAbbt,
    required this.roomName,
    required this.buildingName,
    required this.buildingNo,
    required this.roomNo,
    required this.typeCd,
  });

  factory SjptFacility.fromJson(Map<String, dynamic> j) => SjptFacility(
    roomAbbt: (j['ROOM_ABBT'] as String?) ?? '',
    roomName: (j['ROOM_NM'] as String?) ?? '',
    buildingName: (j['BLD_NM'] as String?) ?? '',
    buildingNo: (j['BLD_NO'] as String?) ?? '',
    roomNo: (j['ROOM_NO'] as String?) ?? '',
    typeCd: (j['INST_TP_CD'] as String?) ?? '',
  );

  final String roomAbbt;
  final String roomName;
  final String buildingName;
  final String buildingNo;
  final String roomNo;
  final String typeCd;
}

/// 예약 가능 시설 인스턴스 (doListInst.do) — FACILITY_MNGT_NO 포함.
class SjptFacilityInstance {
  const SjptFacilityInstance({
    required this.facilityMngtNo,
    required this.roomAbbt,
    required this.roomName,
    required this.buildingName,
    required this.buildingNo,
    required this.roomNo,
    required this.typeCd,
    required this.maxCapacity,
    required this.minPeople,
    required this.useTimeFrom,
    required this.useTimeTo,
    required this.notes,
    required this.cableMicCount,
    required this.wirelessMicCount,
    required this.hasElecTable,
    required this.hasElecApproval,
    required this.directYn,
    required this.operDeptName,
    required this.remark,
  });

  factory SjptFacilityInstance.fromJson(Map<String, dynamic> j) =>
      SjptFacilityInstance(
        facilityMngtNo: (j['FACILITY_MNGT_NO'] as String?) ?? '',
        roomAbbt: (j['ROOM_ABBT'] as String?) ?? '',
        roomName: (j['ROOM_NM'] as String?) ?? '',
        buildingName: (j['BLD_NM'] as String?) ?? '',
        buildingNo: (j['BLD_NO'] as String?) ?? '',
        roomNo: (j['ROOM_NO'] as String?) ?? '',
        typeCd: (j['INST_TP_CD'] as String?) ?? '',
        maxCapacity: (j['MAX_ADMT_NMPR'] as num?)?.toInt() ?? 0,
        minPeople: (j['MIN_USE_NMPR'] as num?)?.toInt() ?? 1,
        useTimeFrom: (j['USE_TIME_1'] as String?) ?? '',
        useTimeTo: (j['USE_TIME_2'] as String?) ?? '',
        notes: (j['MATDT'] as String?) ?? '',
        cableMicCount: (j['CBLE_MIC_QNT'] as num?)?.toInt() ?? 0,
        wirelessMicCount: (j['WRLESS_MIC_QNT'] as num?)?.toInt() ?? 0,
        hasElecTable: j['ELEC_TBL_FLAG'] == 'Y',
        hasElecApproval: j['ELEC_APRV_YN'] == 'Y',
        directYn: (j['DIRECT_YN'] as String?) ?? 'N',
        operDeptName: (j['OPER_DEPT_NM'] as String?) ?? '',
        remark: (j['REMARK'] as String?) ?? '',
      );

  final String facilityMngtNo;
  final String roomAbbt;
  final String roomName;
  final String buildingName;
  final String buildingNo;
  final String roomNo;
  final String typeCd;
  final int maxCapacity;
  final int minPeople;
  final String useTimeFrom; // "0900"
  final String useTimeTo; // "2200"
  final String notes;
  final int cableMicCount;
  final int wirelessMicCount;
  final bool hasElecTable;
  final bool hasElecApproval;
  final String directYn;
  final String operDeptName;
  final String remark;

  bool get isReservable => facilityMngtNo.isNotEmpty;
}

/// 시간대별 예약 현황 슬롯 (doListInstTimeTable.do 응답 1건).
class SjptTimeSlot {
  const SjptTimeSlot({
    required this.roomAbbt,
    required this.useDate,
    required this.timeFrom,
    required this.timeTo,
    required this.period,
    required this.applicantName,
    required this.deptName,
    required this.purpose,
    required this.phone,
    required this.remark,
    required this.facilityMngtNo,
    required this.buildingNo,
    required this.buildingName,
    required this.roomNo,
    required this.roomName,
    required this.typeCd,
    required this.maxCapacity,
    required this.minPeople,
    this.placeDivCd = '',
  });

  factory SjptTimeSlot.fromJson(Map<String, dynamic> j) => SjptTimeSlot(
    roomAbbt: (j['ROOM_ABBT'] as String?) ?? '',
    useDate: (j['USE_DT'] as String?) ?? '',
    timeFrom: (j['TIME_FROM'] as String?) ?? '',
    timeTo: (j['TIME_TO'] as String?) ?? '',
    period: (j['PERIOD'] as String?) ?? '',
    applicantName: (j['APPLCNT_NM'] as String?) ?? '',
    deptName: (j['PSTN_DEPT_NM'] as String?) ?? '',
    purpose: (j['USE_PURP'] as String?) ?? '',
    phone: (j['PHONE'] as String?) ?? '',
    remark: (j['REMARK'] as String?) ?? '',
    facilityMngtNo: (j['FACILITY_MNGT_NO'] as String?) ?? '',
    buildingNo: (j['BLD_NO'] as String?) ?? '',
    buildingName: (j['BLD_NM'] as String?) ?? '',
    roomNo: (j['ROOM_NO'] as String?) ?? '',
    roomName: (j['ROOM_NM'] as String?) ?? '',
    typeCd: (j['INST_TP_CD'] as String?) ?? '',
    maxCapacity: (j['MAX_ADMT_NMPR'] as num?)?.toInt() ?? 0,
    minPeople: (j['MIN_USE_NMPR'] as num?)?.toInt() ?? 1,
    placeDivCd: (j['PLACE_DIV_CD'] as String?) ?? '',
  );

  final String roomAbbt;
  final String useDate;
  final String timeFrom; // "09:00"
  final String timeTo; // "09:30"
  final String period; // "1교시"
  final String applicantName; // "예약가능" 이면 isAvailable=true
  final String deptName; // 소속부서
  final String purpose; // 사용목적
  final String phone; // 전화번호
  final String remark;
  final String facilityMngtNo;
  final String buildingNo;
  final String buildingName;
  final String roomNo;
  final String roomName;
  final String typeCd;
  final int maxCapacity;
  final int minPeople;
  final String placeDivCd; // PLACE_DIV_CD (doListUseInst 검색용)

  /// APPLCNT_NM == '예약가능' → 예약 가능 슬롯.
  bool get isAvailable => applicantName == '예약가능';
}

/// doListUseInst.do — 시설물 예약 신청번호 조회 결과 1건.
class SjptSlotReservation {
  const SjptSlotReservation({
    required this.useApplyNo,
    required this.useTime,
    required this.treatStatusNm,
    required this.regDttm,
  });

  factory SjptSlotReservation.fromJson(Map<String, dynamic> j) =>
      SjptSlotReservation(
        useApplyNo: (j['USE_APPLY_NO'] as String?) ?? '',
        useTime: (j['USE_TIME'] as String?) ?? '',
        treatStatusNm: (j['TREAT_STATUS_NM'] as String?) ?? '',
        regDttm: (j['REG_DTTM'] as String?) ?? '',
      );

  final String useApplyNo; // "2026735579"
  final String useTime; // "09:00~09:30"
  final String treatStatusNm; // "사용승인완료"
  final String regDttm; // "2026-05-27"

  /// "09:00~09:30" → ("09:00", "09:30")
  (String, String)? get timeParts {
    final parts = useTime.split('~');
    if (parts.length != 2) return null;
    return (parts[0].trim(), parts[1].trim());
  }

  /// 슬롯의 timeFrom이 이 예약 범위에 포함되는지.
  bool containsSlot(String slotTimeFrom) {
    final p = timeParts;
    if (p == null) return false;
    return p.$1.compareTo(slotTimeFrom) <= 0 &&
        p.$2.compareTo(slotTimeFrom) > 0;
  }
}

/// 내 예약 내역 1건 (doListInstUseAply.do).
class SjptReservation {
  const SjptReservation({
    required this.useApplyNo,
    required this.facilityName,
    required this.roomAbbt,
    required this.buildingName,
    required this.buildingNo,
    required this.roomNo,
    required this.useDateStart,
    required this.useDateEnd,
    required this.beginTime,
    required this.endTime,
    required this.treatStatusNm,
    required this.treatStatusCd,
    required this.purpose,
    required this.usePeople,
    required this.regDate,
    required this.phoneNo,
    required this.orgName,
    required this.deptName,
    required this.advisorName,
  });

  factory SjptReservation.fromJson(Map<String, dynamic> j) => SjptReservation(
    useApplyNo: (j['USE_APPLY_NO'] as String?) ?? '',
    facilityName: (j['FACILITY_NM'] as String?) ?? '',
    roomAbbt: (j['ROOM_ABBT'] as String?) ?? '',
    buildingName: (j['BLD_NM'] as String?) ?? '',
    buildingNo: (j['BLD_NO'] as String?) ?? '',
    roomNo: (j['ROOM_NO'] as String?) ?? '',
    useDateStart: (j['USE_BGN_DT'] as String?) ?? '',
    useDateEnd: (j['USE_END_DT'] as String?) ?? '',
    beginTime: (j['USE_BGN_TIME'] as String?) ?? '',
    endTime: (j['USE_FSHTM'] as String?) ?? '',
    treatStatusNm: (j['TREAT_STATUS_NM'] as String?) ?? '',
    treatStatusCd: (j['TREAT_STATUS_CD'] as String?) ?? '',
    purpose: (j['USE_PURP'] as String?) ?? '',
    usePeople: (j['USE_NMPR'] as num?)?.toInt() ?? 0,
    regDate: (j['REG_DTTM'] as String?) ?? '',
    phoneNo: (j['PHONE_NO'] as String?) ?? '',
    orgName: (j['PSTN_ASO_NM'] as String?) ?? '',
    deptName: (j['PSTN_DEPT_NM'] as String?) ?? '',
    advisorName: (j['MAP_PROF_NM'] as String?) ?? '',
  );

  final String useApplyNo;
  final String facilityName;
  final String roomAbbt;
  final String buildingName;
  final String buildingNo;
  final String roomNo;
  final String useDateStart; // yyyyMMdd
  final String useDateEnd;
  final String beginTime; // "09:00"
  final String endTime; // "09:30"
  final String treatStatusNm;
  final String treatStatusCd;
  final String purpose;
  final int usePeople;
  final String regDate; // "2026-05-27"
  final String phoneNo; // "010-5779-3074"
  final String orgName; // 소속단체명
  final String deptName; // 소속학과
  final String advisorName; // 지도교수명

  bool get isPending =>
      treatStatusCd == 'GAI041001' ||
      treatStatusCd == 'GAI041010' ||
      treatStatusCd.isEmpty;
  bool get isApproved =>
      treatStatusCd == 'GAI041002' || treatStatusCd == 'GAI041011';
  bool get isCancelled => treatStatusCd == 'GAI041005';
}
