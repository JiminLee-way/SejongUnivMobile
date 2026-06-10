import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_notifications.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_controller.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_settings_provider.dart';

/// UCheck 우상단 설정 아이콘 → 모달.
///
/// 항목:
/// - **자동출석 ON/OFF** 토글 — 처음 ON 시 notification 권한 요청 + notification
///   예약 + 즉시 trigger
/// - **테스트 트리거** — 디버그용. 즉시 checkAndTrigger.
class UCheckSettingsScreen extends ConsumerWidget {
  const UCheckSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEnabled = ref.watch(autoAttendEnabledProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Symbols.settings, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('UCheck 설정', style: AppTypography.headlineMd),
                ],
              ),
              const SizedBox(height: 20),
              _AutoAttendToggleCard(asyncEnabled: asyncEnabled),
              const SizedBox(height: 12),
              const _NotificationToggleCard(),
              const SizedBox(height: 12),
              const _HowItWorksCard(),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(autoAttendControllerProvider.notifier)
                      .checkAndTrigger(reason: 'settings_manual_test');
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('지금 자동출석을 시도해요 (현재 시각이 강의 시간대일 때만 동작)'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Symbols.bolt, size: 18),
                label: const Text('지금 자동출석 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoAttendToggleCard extends ConsumerWidget {
  const _AutoAttendToggleCard({required this.asyncEnabled});
  final AsyncValue<bool> asyncEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = asyncEnabled.value ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('자동출석', style: AppTypography.headlineMd),
                    const SizedBox(height: 4),
                    Text(
                      '강의 시작 10분 전 알림 + 앱을 켤 때마다 BLE 스캔으로 자동 출석체크',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: enabled,
                onChanged: asyncEnabled.isLoading
                    ? null
                    : (v) => _onToggle(context, ref, v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    await ref.read(autoAttendEnabledProvider.notifier).setEnabled(value);
    if (value) {
      // ON → 알림 권한 요청 + 즉시 trigger + notification 예약
      final granted = await UCheckNotifications.instance.requestPermission();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 권한이 거부됐어요. 설정에서 허용해주세요.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      await ref
          .read(autoAttendControllerProvider.notifier)
          .scheduleNotificationsForToday();
      ref
          .read(autoAttendControllerProvider.notifier)
          .checkAndTrigger(reason: 'toggle_on');
    } else {
      // OFF → 예약된 모든 알림 cancel
      await ref
          .read(autoAttendControllerProvider.notifier)
          .scheduleNotificationsForToday();
    }
  }
}

/// 자동출석과 무관한 두 알림(출석 가능 시간 시작 / 수업 정각) 토글 묶음.
/// 둘 다 켜면 약 10분 사이로 두 번 울리므로 기본값은 attend_open만 ON.
class _NotificationToggleCard extends ConsumerWidget {
  const _NotificationToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOpen = ref.watch(attendOpenNotifEnabledProvider);
    final asyncStart = ref.watch(classStartNotifEnabledProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.notifications, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('수업 알림', style: AppTypography.headlineMd),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '공휴일은 자동으로 제외되고, 향후 7일치를 미리 예약합니다.',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _NotifRow(
            title: '출석 시간 시작 알림',
            subtitle: '강의 시작 10분 전, 출석 가능 시간이 열릴 때',
            asyncEnabled: asyncOpen,
            onChanged: (v) async {
              await ref
                  .read(attendOpenNotifEnabledProvider.notifier)
                  .setEnabled(v);
              await ref
                  .read(autoAttendControllerProvider.notifier)
                  .scheduleClassReminders();
              if (v && context.mounted) {
                // 첫 ON 시 권한 요청.
                await UCheckNotifications.instance.requestPermission();
              }
            },
          ),
          _NotifRow(
            title: '수업 시작 알림',
            subtitle: '강의 시작 정각',
            asyncEnabled: asyncStart,
            onChanged: (v) async {
              await ref
                  .read(classStartNotifEnabledProvider.notifier)
                  .setEnabled(v);
              await ref
                  .read(autoAttendControllerProvider.notifier)
                  .scheduleClassReminders();
              if (v && context.mounted) {
                await UCheckNotifications.instance.requestPermission();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.title,
    required this.subtitle,
    required this.asyncEnabled,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final AsyncValue<bool> asyncEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = asyncEnabled.value ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: enabled,
            onChanged: asyncEnabled.isLoading ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.info, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '어떻게 동작하나요?',
                style: AppTypography.labelMd.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• 강의 시작 10분 전 OS 알림이 떠요\n'
            '• 알림을 탭하거나 앱을 열면 자동으로 BLE 스캔 + 출석 처리\n'
            '• 강의실 안에 있어야 비콘이 잡혀요 (보통 1~10초)\n'
            '• 잠자기/절전모드에서 깨어 앱을 열어도 자동 동작\n'
            '• 백그라운드 자동출석은 OneUI 제약으로 미지원',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 모달 helper.
Future<void> showUCheckSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const UCheckSettingsScreen(),
  );
}
