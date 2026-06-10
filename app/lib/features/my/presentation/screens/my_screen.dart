import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/routing/menu_route_helper.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/features/academic/presentation/screens/grades_screen.dart';
import 'package:sejong_smart_campus/core/demo/demo.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/auth/presentation/screens/auth_gate.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/library/presentation/providers/library_providers.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:sejong_smart_campus/features/student_id/presentation/providers/student_id_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';

/// MY 페이지 — sjapp `/usr/dashboard` 미러.
///
/// 사용자 정보 + 학사·도서·알림 빠른 진입 + 로그아웃.
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃하시겠어요?'),
        content: const Text('저장된 토큰과 자동 로그인 정보를 모두 삭제해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('로그아웃', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authStateProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushAndRemoveUntil(instantRoute(const AuthGate()), (_) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final user = ref.watch(displayUserProvider);
    final photoBytes = ref.watch(myPhotoProvider).value;
    final loan = ref.watch(loanInfoProvider).value;
    final today = ref.watch(calendarDateProvider);
    final myToday = ref.watch(studentDailyAllProvider(today)).value;

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: ListView(
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
                  _ProfileCard(user: user, photoBytes: photoBytes),
                  const SizedBox(height: AppSpacing.stackMd),
                  _QuickStatsRow(
                    loanCount: loan?.loanCount,
                    overDueCount: loan?.overDueCount,
                    todayCount: myToday?.length,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  GlassCard(
                    borderRadius: AppRadius.xl,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _HubRow(
                          icon: Symbols.calendar_month,
                          label: '학사 캘린더',
                          subtitle: '세종대학교 공식 학사일정',
                          onTap: () => openAcademicCalendar(context),
                        ),
                        const Divider(height: 1),
                        _HubRow(
                          icon: Symbols.trending_up,
                          label: '전체학기 성적',
                          subtitle: '학기별 평점·환산점수',
                          onTap: () => Navigator.of(
                            context,
                          ).push(slideRoute(const GradesScreen())),
                        ),
                        const Divider(height: 1),
                        _HubRow(
                          icon: Symbols.notifications,
                          label: '알림함',
                          subtitle: '학교 공식 메시지',
                          onTap: () => Navigator.of(
                            context,
                          ).push(slideRoute(const NotificationsScreen())),
                        ),
                        const Divider(height: 1),
                        _HubRow(
                          icon: Symbols.tune,
                          label: '알림 설정',
                          subtitle: '카테고리별 푸시 on/off',
                          onTap: () => Navigator.of(context).push(
                            slideRoute(const NotificationSettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  const _SearchVisibilityCard(),
                  const SizedBox(height: AppSpacing.stackMd),
                  GlassCard(
                    borderRadius: AppRadius.xl,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _HubRow(
                      icon: Symbols.logout,
                      label: '로그아웃',
                      subtitle: '저장된 토큰 + 자동 로그인 해제',
                      destructive: true,
                      onTap: () => _logout(context, ref),
                    ),
                  ),
                ],
              ),
            ),
            const Align(alignment: Alignment.topCenter, child: _MyAppBar()),
          ],
        ),
      ),
    );
  }
}

class _MyAppBar extends StatelessWidget {
  const _MyAppBar();
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
            'MY 세종',
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.photoBytes});
  final dynamic user; // SejongUser?
  final dynamic photoBytes;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE4E6), Color(0xFFFFD1D7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: photoBytes != null
                ? Image.memory(photoBytes, fit: BoxFit.cover)
                : Icon(
                    Symbols.person,
                    size: 48,
                    fill: 1,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? '—',
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user == null
                      ? '—'
                      : '${user.departmentName} · ${user.studentYear}학년',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (user?.userId != null)
                      _MetaChip(text: '학번 ${user.userId}'),
                    if (user?.statusName != null)
                      _MetaChip(text: user.statusName, highlight: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text, this.highlight = false});
  final String text;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.32)
              : AppColors.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          fontSize: 11,
          color: highlight ? AppColors.primary : AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.loanCount,
    required this.overDueCount,
    required this.todayCount,
  });
  final int? loanCount;
  final int? overDueCount;
  final int? todayCount;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Symbols.menu_book,
          label: '대출 도서',
          value: loanCount?.toString() ?? '—',
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: Symbols.warning,
          label: '연체',
          value: overDueCount?.toString() ?? '—',
          highlight: (overDueCount ?? 0) > 0,
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: Symbols.event,
          label: '오늘 학사',
          value: todayCount?.toString() ?? '—',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: highlight ? AppColors.primary : AppColors.onSurface,
              fill: 1,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.labelMd.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.primary : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "친구 검색 허용" 토글 — 끄면 다른 학생의 학번·이름 검색 결과에서 빠진다.
/// 기본 노출(opt-out). 서버 `users.searchable` ↔ [searchVisibilityProvider].
class _SearchVisibilityCard extends ConsumerWidget {
  const _SearchVisibilityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchVisibilityProvider);
    final on = async.value ?? true;
    final loading = async.isLoading;

    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.person_search,
              size: 20,
              color: AppColors.onSurface,
              fill: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '친구 검색 허용',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '다른 학생이 학번·이름으로 나를 찾을 수 있어요',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: loading
                ? null
                : (v) async {
                    try {
                      await ref.read(searchVisibilityProvider.notifier).set(v);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('변경에 실패했어요. 잠시 후 다시 시도해 주세요.'),
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.primary : AppColors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceContainerLowest.withValues(
                          alpha: 0.85,
                        ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color, fill: 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right,
                size: 20,
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
