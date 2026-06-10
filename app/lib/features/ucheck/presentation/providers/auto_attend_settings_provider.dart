import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_settings_local.dart';

final ucheckSettingsLocalProvider = Provider<UCheckSettingsLocal>(
  (ref) => UCheckSettingsLocal(),
);

/// 자동출석 토글 상태 — UI는 이걸 watch. 첫 build에서 secure storage 비동기
/// 읽기 후 emit. 토글 시 즉시 state + storage 둘 다 갱신.
class AutoAttendEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final local = ref.watch(ucheckSettingsLocalProvider);
    return local.readAutoAttendEnabled();
  }

  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    final local = ref.read(ucheckSettingsLocalProvider);
    await local.writeAutoAttendEnabled(value);
  }

  Future<void> toggle() async {
    final current = state.value ?? false;
    await setEnabled(!current);
  }
}

final autoAttendEnabledProvider =
    AsyncNotifierProvider<AutoAttendEnabledNotifier, bool>(
      AutoAttendEnabledNotifier.new,
    );

/// "출석 시간 시작" 알림 토글. 자동출석과 독립 — OFF여도 단순 알림으로 동작.
class AttendOpenNotifEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final local = ref.watch(ucheckSettingsLocalProvider);
    return local.readAttendOpenNotifEnabled();
  }

  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    final local = ref.read(ucheckSettingsLocalProvider);
    await local.writeAttendOpenNotifEnabled(value);
  }
}

final attendOpenNotifEnabledProvider =
    AsyncNotifierProvider<AttendOpenNotifEnabledNotifier, bool>(
      AttendOpenNotifEnabledNotifier.new,
    );

/// "수업 시작 정각" 알림 토글.
class ClassStartNotifEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final local = ref.watch(ucheckSettingsLocalProvider);
    return local.readClassStartNotifEnabled();
  }

  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    final local = ref.read(ucheckSettingsLocalProvider);
    await local.writeClassStartNotifEnabled(value);
  }
}

final classStartNotifEnabledProvider =
    AsyncNotifierProvider<ClassStartNotifEnabledNotifier, bool>(
      ClassStartNotifEnabledNotifier.new,
    );
