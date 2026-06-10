import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/notifications/data/datasources/sejong_notifications_remote.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';

/// 알림 설정 — 19개 카테고리 on/off + 마스터 스위치.
///
/// sjapp `/api/v1/ums/notification-settings` 미러. 필수 카테고리는 토글 비활성.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(notificationSettingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final async = ref.watch(notificationSettingsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: SejongRefresh(
                onRefresh: () => _onRefresh(ref),
                topInset: mq.padding.top + 64,
                child: async.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (_, _) => Center(
                    child: Text(
                      '알림 설정을 불러오지 못했어요',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  data: (s) => ListView(
                    padding: EdgeInsets.only(
                      top: mq.padding.top + 64 + 16,
                      left: AppSpacing.marginMobile,
                      right: AppSpacing.marginMobile,
                      bottom: 120 + mq.padding.bottom,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      _MasterSwitchCard(enabled: s.masterEnabled),
                      const SizedBox(height: 16),
                      Text(
                        '카테고리별 알림',
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GlassCard(
                        borderRadius: AppRadius.xl,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (var i = 0; i < s.settings.length; i++) ...[
                              _CategoryRow(
                                cat: s.settings[i],
                                masterOn: s.masterEnabled,
                              ),
                              if (i != s.settings.length - 1)
                                const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Align(alignment: Alignment.topCenter, child: _AppBar()),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar();
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: top + 64,
      padding: EdgeInsets.only(top: top, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Symbols.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '알림 설정',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterSwitchCard extends ConsumerWidget {
  const _MasterSwitchCard({required this.enabled});
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          const Icon(
            Symbols.notifications,
            size: 22,
            fill: 1,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 알림',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  enabled ? '모든 알림 카테고리가 활성화 가능' : '모든 알림이 차단됨',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => toggleMasterNotifications(ref, v),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.cat, required this.masterOn});
  final NotificationCategorySetting cat;
  final bool masterOn;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabled = !masterOn || cat.mandatoryFlag;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _tintFor(cat.iconColor).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              cat.categoryCode == 'LECTURE_NOTICE' ||
                      cat.categoryCode == 'ETC_NOTICE'
                  ? Symbols.notifications
                  : Symbols.campaign,
              size: 18,
              color: _tintFor(cat.iconColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    cat.categoryName,
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cat.mandatoryFlag) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '필수',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: cat.isEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: disabled
                ? null
                : (v) => toggleNotificationCategory(ref, cat.categoryId, v),
          ),
        ],
      ),
    );
  }

  Color _tintFor(String? bgClass) {
    // tailwind 색 → 우리 토큰 대략 매핑.
    if (bgClass == null) return AppColors.primary;
    if (bgClass.contains('red')) return AppColors.primary;
    if (bgClass.contains('blue')) return const Color(0xFF0284C7);
    if (bgClass.contains('green')) return const Color(0xFF059669);
    if (bgClass.contains('yellow') || bgClass.contains('orange')) {
      return const Color(0xFFD97706);
    }
    if (bgClass.contains('cyan')) return const Color(0xFF06B6D4);
    if (bgClass.contains('purple') || bgClass.contains('pink')) {
      return const Color(0xFF7C3AED);
    }
    if (bgClass.contains('gray')) return AppColors.outline;
    return AppColors.primary;
  }
}
