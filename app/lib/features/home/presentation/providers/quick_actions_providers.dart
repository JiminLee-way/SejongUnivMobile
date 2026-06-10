import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/home/data/datasources/quick_actions_storage.dart';
import 'package:sejong_smart_campus/features/home/domain/entities/quick_action.dart';

final _storageProvider = Provider<QuickActionsStorage>(
  (_) => QuickActionsStorage(),
);

/// 홈 바로가기 키 리스트. AsyncNotifier 패턴 ([MenuOrderNotifier]와 동일).
/// 저장 파일이 없으면 [kDefaultQuickActionKeys]로 fallback.
class QuickActionsNotifier extends AsyncNotifier<List<String>> {
  QuickActionsStorage get _storage => ref.read(_storageProvider);

  @override
  Future<List<String>> build() async {
    final saved = await _storage.load();
    return saved ?? List<String>.from(kDefaultQuickActionKeys);
  }

  Future<void> setOrder(List<String> keys) async {
    state = AsyncData(List<String>.from(keys));
    await _storage.save(keys);
  }

  Future<void> add(String key) async {
    final current = state.value ?? [];
    if (current.contains(key)) return;
    if (current.length >= kQuickActionsMaxCount) return;
    final next = [...current, key];
    state = AsyncData(next);
    await _storage.save(next);
  }

  Future<void> remove(String key) async {
    final current = state.value ?? [];
    if (!current.contains(key)) return;
    final next = current.where((k) => k != key).toList();
    state = AsyncData(next);
    await _storage.save(next);
  }

  Future<void> reset() async {
    final defaults = List<String>.from(kDefaultQuickActionKeys);
    state = AsyncData(defaults);
    await _storage.clear();
  }
}

final quickActionsProvider =
    AsyncNotifierProvider<QuickActionsNotifier, List<String>>(
      QuickActionsNotifier.new,
    );

/// 편집 모드 토글 상태. 화면 안에서만 유효 — 영속화 X.
class QuickActionsEditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void enter() => state = true;
  void exit() => state = false;
}

final quickActionsEditModeProvider =
    NotifierProvider<QuickActionsEditModeNotifier, bool>(
      QuickActionsEditModeNotifier.new,
    );
