import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';

/// 시설물 예약 내역 서버 캐시.
///
/// 서버 캐시용 — SJPT API가 로그인 세션이 필요해 오프라인/재시작 후에도
/// 신청번호를 확인할 수 있도록 앱 DB에 저장한다.
class SjptReservationRepository {
  SjptReservationRepository({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  /// 예약 완료 후 로컬 캐시에 저장.
  Future<void> saveReservation({
    required String useApplyNo,
    required String bldNm,
    required String bldNo,
    required String roomAbbt,
    required String roomNm,
    required String roomNo,
    required String useBgnDt,
    required String useEndDt,
    required String bgnTime,
    required String endTime,
    required String purpose,
    required int usePeople,
    String orgName = '',
    String advisorNm = '',
    String statusNm = '',
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    final applyDt = DateTime.now().toIso8601String().substring(0, 10);

    await _db.from(SupabaseConfig.tableSjptReservations).upsert({
      'user_id': uid,
      'use_apply_no': useApplyNo,
      'bld_nm': bldNm,
      'bld_no': bldNo,
      'room_abbt': roomAbbt,
      'room_nm': roomNm,
      'room_no': roomNo,
      'apply_dt': applyDt,
      'use_bgn_dt': useBgnDt,
      'use_end_dt': useEndDt,
      'bgn_time': bgnTime,
      'end_time': endTime,
      'purpose': purpose,
      'use_people': usePeople,
      'org_name': orgName,
      'advisor_nm': advisorNm,
      'status_nm': statusNm,
    }, onConflict: 'use_apply_no');
  }

  /// 내 예약 내역 조회 (최신순).
  Future<List<SjptLocalReservation>> loadReservations() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await _db
        .from(SupabaseConfig.tableSjptReservations)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SjptLocalReservation.fromRow)
        .toList();
  }

  /// 신청번호로 로컬 캐시 업데이트 (처리상태 갱신).
  Future<void> updateStatus(String useApplyNo, String statusNm) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db
        .from(SupabaseConfig.tableSjptReservations)
        .update({'status_nm': statusNm})
        .eq('use_apply_no', useApplyNo)
        .eq('user_id', uid);
  }
}

/// Supabase 로컬 캐시의 예약 한 건.
class SjptLocalReservation {
  const SjptLocalReservation({
    required this.id,
    required this.useApplyNo,
    required this.bldNm,
    required this.bldNo,
    required this.roomAbbt,
    required this.roomNm,
    required this.useBgnDt,
    required this.useEndDt,
    required this.bgnTime,
    required this.endTime,
    required this.purpose,
    required this.usePeople,
    required this.applyDt,
    required this.orgName,
    required this.advisorNm,
    required this.statusNm,
    required this.createdAt,
  });

  factory SjptLocalReservation.fromRow(Map<String, dynamic> r) =>
      SjptLocalReservation(
        id: (r['id'] as String?) ?? '',
        useApplyNo: (r['use_apply_no'] as String?) ?? '',
        bldNm: (r['bld_nm'] as String?) ?? '',
        bldNo: (r['bld_no'] as String?) ?? '',
        roomAbbt: (r['room_abbt'] as String?) ?? '',
        roomNm: (r['room_nm'] as String?) ?? '',
        useBgnDt: (r['use_bgn_dt'] as String?) ?? '',
        useEndDt: (r['use_end_dt'] as String?) ?? '',
        bgnTime: (r['bgn_time'] as String?) ?? '',
        endTime: (r['end_time'] as String?) ?? '',
        purpose: (r['purpose'] as String?) ?? '',
        usePeople: (r['use_people'] as int?) ?? 0,
        applyDt: (r['apply_dt'] as String?) ?? '',
        orgName: (r['org_name'] as String?) ?? '',
        advisorNm: (r['advisor_nm'] as String?) ?? '',
        statusNm: (r['status_nm'] as String?) ?? '',
        createdAt: r['created_at'] as String? ?? '',
      );

  final String id;
  final String useApplyNo;
  final String bldNm;
  final String bldNo;
  final String roomAbbt;
  final String roomNm;
  final String useBgnDt;
  final String useEndDt;
  final String bgnTime;
  final String endTime;
  final String purpose;
  final int usePeople;
  final String applyDt;
  final String orgName;
  final String advisorNm;
  final String statusNm;
  final String createdAt;

  /// "20260528" → "2026.05.28"
  String get formattedBgnDate {
    if (useBgnDt.length != 8) return useBgnDt;
    return '${useBgnDt.substring(0, 4)}.${useBgnDt.substring(4, 6)}.${useBgnDt.substring(6)}';
  }

  String get timeLabel => '$bgnTime ~ $endTime';
}
