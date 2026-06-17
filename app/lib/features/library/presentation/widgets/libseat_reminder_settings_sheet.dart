import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notifications.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_reminder_settings_local.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';

Future<void> showLibseatReminderSettingsSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LibseatReminderSettingsSheet(),
  );
}

class _LibseatReminderSettingsSheet extends ConsumerStatefulWidget {
  const _LibseatReminderSettingsSheet();

  @override
  ConsumerState<_LibseatReminderSettingsSheet> createState() =>
      _LibseatReminderSettingsSheetState();
}

class _LibseatReminderSettingsSheetState
    extends ConsumerState<_LibseatReminderSettingsSheet> {
  LibseatReminderSettings _settings = LibseatReminderSettings.defaults;
  bool _loading = true;
  bool _saving = false;
  bool _notificationGranted = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final settings = await ref
        .read(libseatReminderSettingsLocalProvider)
        .read();
    final granted = await _readNotificationGranted();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _notificationGranted = granted;
      _loading = false;
    });
  }

  Future<bool> _readNotificationGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<void> _openNotificationSettings() async {
    await openAppSettings();
    final granted = await _readNotificationGranted();
    if (!mounted) return;
    setState(() => _notificationGranted = granted);
  }

  Future<void> _save(LibseatReminderSettings next) async {
    setState(() {
      _settings = next;
      _saving = true;
    });
    await ref.read(libseatReminderSettingsLocalProvider).write(next);
    ref.invalidate(libseatReminderSettingsProvider);
    await LibseatNotifications.instance.cancelAll();
    unawaited(ref.read(libseatSyncProvider).sync(reason: 'settingsChanged'));
    final granted = await _readNotificationGranted();
    if (!mounted) return;
    setState(() {
      _notificationGranted = granted;
      _saving = false;
    });
  }

  void _setMaster(bool enabled) {
    unawaited(_save(_settings.copyWith(enabled: enabled)));
  }

  void _setMinute(int minute, bool enabled) {
    final minutes = _settings.enabledMinutesBefore.toSet();
    if (enabled) {
      minutes.add(minute);
    } else {
      minutes.remove(minute);
    }
    unawaited(_save(_settings.copyWith(enabledMinutesBefore: minutes)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ambientShadow,
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 18),
        child: _loading
            ? const _SettingsLoading()
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Symbols.notifications_active,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '열람실 알림 설정',
                          style: AppTypography.headlineMd.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_saving)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  if (_settings.enabled && !_notificationGranted) ...[
                    const SizedBox(height: 16),
                    _PermissionBanner(
                      onOpenSettings: _openNotificationSettings,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SwitchRow(
                    title: '열람실 대여 시간 알림',
                    subtitle: '예약 종료 전 선택한 시점에 알림을 받아요',
                    value: _settings.enabled,
                    onChanged: _setMaster,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount:
                          LibseatReminderSettings.supportedMinutesBefore.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final minute = LibseatReminderSettings
                            .supportedMinutesBefore[index];
                        return _SwitchRow(
                          title: libseatReminderLabel(minute),
                          value: _settings.enabledMinutesBefore.contains(
                            minute,
                          ),
                          enabled: _settings.enabled,
                          onChanged: (value) => _setMinute(minute, value),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 240,
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.notification_important,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '알림 권한 허용이 필요해요',
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onOpenSettings, child: const Text('설정으로 이동')),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.onSurface : AppColors.onSurfaceVariant;
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelMd.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
