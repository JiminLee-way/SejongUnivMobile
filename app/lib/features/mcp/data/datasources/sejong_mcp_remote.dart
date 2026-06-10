import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';

/// AI 어시스턴트(MCP) 백엔드.
///   - GET  `/api/v1/mcp/context/greeting` — 첫 진입 인사말
///   - POST `/api/v1/mcp/chat`             — 메시지 send/receive
///   - GET  `/api/v1/mcp/sessions`         — 대화 세션 list
///   - GET  `/api/v1/mcp/recommendations/questions` — 추천 질문
///   - GET  `/api/v1/mcp/knowledge/search?q=`       — 지식 검색
///
/// 응답 스키마는 best-effort 매핑. 추후 실제 응답 보고 보강.
class SejongMcpRemote {
  SejongMcpRemote({required this.client});
  final SejongApiClient client;

  static const _prefix = '/api/v1/mcp';

  Future<String?> fetchGreeting() async {
    try {
      final res = await client.dio.get<dynamic>('$_prefix/context/greeting');
      return client.unwrap<String?>(res, (raw) {
        if (raw is String) return raw;
        if (raw is Map<String, dynamic>) {
          for (final k in ['greeting', 'message', 'text', 'content']) {
            final v = raw[k];
            if (v is String && v.isNotEmpty) return v;
          }
        }
        return null;
      });
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> fetchRecommendedQuestions() async {
    try {
      final res = await client.dio.get<dynamic>(
        '$_prefix/recommendations/questions',
      );
      return client.unwrap<List<String>>(res, (raw) {
        if (raw is List) {
          return raw
              .map(
                (e) => e is String
                    ? e
                    : (e is Map<String, dynamic>
                          ? (e['question'] ?? e['text'] ?? '').toString()
                          : ''),
              )
              .where((s) => s.isNotEmpty)
              .toList();
        }
        return const [];
      });
    } catch (_) {
      return const [];
    }
  }

  /// 메시지 전송. 응답 모양 미상 — `text`/`reply`/`message` 후보 키 매핑.
  Future<String?> sendChat(String message, {String? sessionId}) async {
    try {
      final res = await client.dio.post<dynamic>(
        '$_prefix/chat',
        data: <String, dynamic>{
          'message': message,
          if (sessionId != null) 'sessionId': sessionId,
        },
      );
      return client.unwrap<String?>(res, (raw) {
        if (raw is String) return raw;
        if (raw is Map<String, dynamic>) {
          for (final k in ['reply', 'message', 'text', 'answer', 'content']) {
            final v = raw[k];
            if (v is String && v.isNotEmpty) return v;
          }
        }
        return null;
      });
    } catch (_) {
      return null;
    }
  }
}
