import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/features/support/domain/entities/support_models.dart';

/// 앱 1:1 문의 Supabase wrapper.
class AppSupportRemote {
  AppSupportRemote(this._client);
  final SupabaseClient _client;

  /// 익명 세션 보장 — auth.uid()가 있어야 insert/select RLS가 통과한다. 로그인 시
  /// 온보딩이 이미 세션을 만들어 두지만(디스크 영속), 만약 없으면 즉석에서 익명
  /// 로그인. 문의의 신원은 reporter_student_id/name이 들고 있어 uid는 RLS 범위용.
  Future<void> _ensureSession() async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
  }

  /// 문의 작성. 학번/이름/진단 컨텍스트/(선택)로그는 클라가 그대로 실어 보낸다.
  /// uid는 서버 default가 채우므로 보내지 않는다.
  Future<void> createInquiry({
    required String category,
    required String title,
    required String content,
    String? reporterStudentId,
    String? reporterName,
    String? appVersion,
    String? platform,
    String? osVersion,
    String? deviceModel,
    String? logExcerpt,
    bool isCrashReport = false,
  }) async {
    await _ensureSession();
    await _client
        .from(SupabaseConfig.tableAppInquiries)
        .insert(<String, dynamic>{
          'category': category,
          'title': title,
          'content': content,
          if (reporterStudentId != null && reporterStudentId.isNotEmpty)
            'reporter_student_id': reporterStudentId,
          if (reporterName != null && reporterName.isNotEmpty)
            'reporter_name': reporterName,
          if (appVersion != null) 'app_version': appVersion,
          if (platform != null) 'platform': platform,
          if (osVersion != null) 'os_version': osVersion,
          if (deviceModel != null) 'device_model': deviceModel,
          if (logExcerpt != null && logExcerpt.isNotEmpty)
            'log_excerpt': logExcerpt,
          'is_crash_report': isCrashReport,
        });
  }

  /// 내 문의 목록(최신순). RLS로 본인 것만 온다.
  Future<List<QnaItem>> listMyInquiries({int limit = 50}) async {
    await _ensureSession();
    final res = await _client
        .from(SupabaseConfig.tableAppInquiries)
        .select('id, title, status, answer, is_crash_report, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(QnaItem.fromInquiryRow)
        .toList();
  }
}
