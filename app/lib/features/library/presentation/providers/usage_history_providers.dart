import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/library/data/datasources/usage_history_local.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';

/// 단일 로컬 저장소 — process-singleton.
final usageHistoryLocalProvider = Provider<UsageHistoryLocal>(
  (_) => UsageHistoryLocal(),
);

/// 사용자의 이용 내역 timeline.
///
/// v1은 로컬 timeline (reserve/return/extend/cancel 시 append).
/// v2 — libseat history endpoint 발견 시 remote merge.
///
/// `currentUserProvider`를 watch해서 로그인 사용자가 바뀌면 자동 재구독.
final usageHistoryProvider =
    FutureProvider.autoDispose<List<LibraryUsageRecord>>((ref) async {
      ref.watch(currentUserProvider);
      final local = ref.watch(usageHistoryLocalProvider);
      return local.getAll();
    });
