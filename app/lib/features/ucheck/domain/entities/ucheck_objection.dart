// UCheck 이의신청(`objectionDetail.do`) 관련 DTO.
//
// 원본: `UCheckDtos.kt`의 `ObjectionDetailResponse`/`ObjectionDetailValue`
// /`ObjectionCode`.

/// `objectionDetail.do` 응답 — 사유 코드 목록 + 이전 제출 내역.
class ObjectionDetailResponse {
  const ObjectionDetailResponse({
    this.result = 0,
    this.attachShowYn = 'N',
    this.objectionCdList = const <ObjectionCode>[],
    this.value,
  });

  /// 1=성공, 그 외 실패.
  final int result;

  /// 첨부파일 입력 노출 여부 (`"Y"`/`"N"`).
  final String attachShowYn;

  /// 이의신청 사유 코드 후보.
  final List<ObjectionCode> objectionCdList;

  /// 기존 제출 내역 (없으면 null).
  final ObjectionDetailValue? value;

  factory ObjectionDetailResponse.fromJson(Map<String, dynamic> json) {
    return ObjectionDetailResponse(
      result: (json['result'] as num?)?.toInt() ?? 0,
      attachShowYn: json['attach_show_yn'] as String? ?? 'N',
      objectionCdList:
          ((json['objection_cd_list'] as List?) ?? const <dynamic>[])
              .map((e) => ObjectionCode.fromJson(e as Map<String, dynamic>))
              .toList(),
      value: json['value'] == null
          ? null
          : ObjectionDetailValue.fromJson(
              json['value'] as Map<String, dynamic>,
            ),
    );
  }
}

/// 이의신청 사유 코드 한 건. `string`은 사용자에게 보여주는 라벨.
class ObjectionCode {
  const ObjectionCode({this.code = '', this.string = ''});

  final String code;

  /// 표시 라벨 (예: `"공식 출장"`, `"병결"`).
  final String string;

  factory ObjectionCode.fromJson(Map<String, dynamic> json) {
    return ObjectionCode(
      code: json['code'] as String? ?? '',
      string: json['string'] as String? ?? '',
    );
  }
}

/// 기존 제출 이의신청의 상세.
///
/// 새 제출이 없으면 `objectionStatus` 등이 모두 null인 비어있는 인스턴스로
/// 내려오기도 한다.
class ObjectionDetailValue {
  const ObjectionDetailValue({
    this.objectionStatus,
    this.objectionCd,
    this.objectionDetail,
    this.objectionReply,
    this.writeDate,
    this.endDate,
    this.beforeStat,
    this.afterStat,
    this.fileNo,
  });

  /// 처리 상태 (`"0"=대기`, `"1"=승인`, `"2"=반려` 등).
  final String? objectionStatus;

  /// 선택한 사유 코드.
  final String? objectionCd;

  /// 학생이 작성한 상세 사유.
  final String? objectionDetail;

  /// 교수/관리자의 답변.
  final String? objectionReply;

  /// 작성일 (`"yyyyMMddHHmmss"`).
  final String? writeDate;

  /// 처리 마감일.
  final String? endDate;

  /// 변경 전 출결 상태 (예: `"3"=결석`).
  final String? beforeStat;

  /// 변경 후 출결 상태.
  final String? afterStat;

  /// 첨부파일 번호.
  final String? fileNo;

  factory ObjectionDetailValue.fromJson(Map<String, dynamic> json) {
    return ObjectionDetailValue(
      objectionStatus: json['objection_status'] as String?,
      objectionCd: json['objection_cd'] as String?,
      objectionDetail: json['objection_detail'] as String?,
      objectionReply: json['objection_reply'] as String?,
      writeDate: json['write_date'] as String?,
      endDate: json['end_date'] as String?,
      beforeStat: json['before_stat'] as String?,
      afterStat: json['after_stat'] as String?,
      fileNo: json['file_no'] as String?,
    );
  }
}
