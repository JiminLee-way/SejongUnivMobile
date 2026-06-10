import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/timetable_providers.dart';

/// ConsumerStatefulWidget build() 안에서 호출 — 지정 학기 시간표가 새로
/// fetch되면 Supabase 서버 함수로 백업 슬롯을 갱신.
///
/// 멱등 — 같은 학기에 동일 데이터 다시 보내도 서버 백업 슬롯을 덮어쓰기.
/// 실패는 silent (sjapp 동작에는 영향 없음).
void useTimetableSync(WidgetRef ref, Semester semester) {
  ref.listen<AsyncValue<Timetable>>(timetableForSemesterProvider(semester), (
    prev,
    next,
  ) {
    final v = next.value;
    if (v == null || v.courses.isEmpty) return;
    unawaited(_pushToSupabase(ref, v));
  });
}

/// 세션당 1회(userId 키) 가드 — 같은 사용자에 대해 전 학기 백업을 중복 실행하지
/// 않는다. 계정이 바뀌면 userId가 달라져 새로 실행, 실패 시 null로 되돌려 재시도.
String? _allSemestersBackupForUser;

/// userId → 이미 백업 성공(또는 빈 학기로 확정)한 학기 name 집합. 미완료 학기만
/// 다음 home build에서 재시도하고, 성공분은 재push하지 않기 위한 진행상태.
final _backedUpSemesters = <String, Set<String>>{};

/// 홈 진입 시 호출 — 로그인한 사용자의 **모든 가용 학기** 시간표를 Supabase에
/// 백업한다(친구가 어떤 학기든 열람 가능하도록). 개별 화면의 [useTimetableSync]는
/// "지금 보고 있는 학기"만 올리므로, 친구 공유를 위해선 한 번에 전 학기를 올려야
/// 한다. 홈은 로그인 직후·앱 재시작 후 모두 거치는 랜딩이라 여기 한 곳에 건다.
void useAllSemestersBackup(WidgetRef ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.userId));
  if (userId == null) return;
  if (_allSemestersBackupForUser == userId) return;
  _allSemestersBackupForUser = userId;
  unawaited(_backupAllSemesters(ref, userId));
}

/// 로그아웃/계정전환 시 [AuthStateNotifier._clearPerUserState]에서 호출 — 전 학기
/// 백업 가드를 풀어 **다음 로그인에서 다시 백업**하도록 한다. 가드는 sjapp userId
/// 키지만, 실제 쓰기를 인가하는 Supabase 익명 세션은 로그아웃/재로그인에 재발급
/// 되므로(같은 사용자 재로그인 포함) teardown에서 함께 리셋해 desync를 막는다.
void resetAllSemestersBackupGuard() {
  _allSemestersBackupForUser = null;
  _backedUpSemesters.clear();
}

Future<void> _backupAllSemesters(WidgetRef ref, String userId) async {
  final done = _backedUpSemesters.putIfAbsent(userId, () => <String>{});
  var anyPending = false; // 로드/업로드 실패한 학기 — 다음 build에서 재시도해야 함
  try {
    final client = ref.read(supabaseClientProvider);
    if (client.auth.currentSession == null) {
      _allSemestersBackupForUser = null; // 세션 준비 전 — 다음 build에서 재시도
      return;
    }
    final semesters = await ref.read(availableSemestersProvider.future);
    for (final sem in semesters) {
      // 계정 전환 가드 — 백업 도중 사용자가 바뀌면 즉시 중단(남의 토큰으로 push 방지).
      if (ref.read(currentUserProvider.select((u) => u?.userId)) != userId)
        return;
      if (done.contains(sem.name)) continue; // 이미 처리한 학기 — skip(재push 안 함).
      try {
        final tt = await ref.read(timetableForSemesterProvider(sem).future);
        if (tt.courses.isEmpty) {
          done.add(sem.name); // 빈 학기 — 완료로 확정(재시도 안 함).
          continue;
        }
        await client.rpc<dynamic>(
          SupabaseConfig.rpcSaveTimetable,
          params: {'p_semester': sem.name, 'p_slots': _serialize(tt)},
        );
        done.add(sem.name);
      } catch (_) {
        anyPending = true; // 이 학기는 다음 기회에 재시도(온보딩 미완료·일시 실패 등).
      }
    }
    // 미완료 학기가 남았으면 가드를 풀어 다음 home build에서 **남은 학기만** 재시도
    // (done에 든 성공분은 위에서 skip). 전부 처리됐으면 가드 유지(중복 방지).
    if (anyPending) _allSemestersBackupForUser = null;
  } catch (_) {
    _allSemestersBackupForUser = null; // 전체 실패(예: 네트워크) — 다음 기회 재시도
  }
}

Future<void> _pushToSupabase(WidgetRef ref, Timetable t) async {
  try {
    final client = ref.read(supabaseClientProvider);
    if (client.auth.currentSession == null) return;
    await client.rpc<dynamic>(
      SupabaseConfig.rpcSaveTimetable,
      params: {'p_semester': t.semester.name, 'p_slots': _serialize(t)},
    );
  } catch (_) {
    // 백업 실패는 sjapp/friend 흐름과 무관. 다음 fetch 때 자동 재시도.
  }
}

Map<String, dynamic> _serialize(Timetable t) => {
  'semester': t.semester.name,
  'courses': [
    for (final c in t.courses)
      {
        'id': c.id,
        'code': c.code,
        'name': c.name,
        'professor': c.professor,
        'location': c.location,
        'credits': c.credits,
        'palette': c.palette.name,
        'times': [
          for (final tm in c.times)
            {
              'weekday': tm.weekday.name,
              'start': '${tm.start.hour}:${tm.start.minute}',
              'end': '${tm.end.hour}:${tm.end.minute}',
            },
        ],
      },
  ],
};
