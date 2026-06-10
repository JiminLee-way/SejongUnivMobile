import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/screens/notification_settings_screen.dart';

/// 통합 설정 화면. 기존에는 ServicesScreen 하단의 _AppSettingsCard로 표시됐던
/// 항목들 + sjapp의 `cmm.setting` leaf가 사용자 입장에서 "설정" 한 곳으로
/// 보이도록 통합. 전체 서비스 메뉴의 "설정" 단일 leaf에서 이 화면으로 진입.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_ios_new, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          '설정',
          style: AppTypography.headlineMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.marginMobile,
          12,
          AppSpacing.marginMobile,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _SettingsRow(
            icon: Symbols.tune,
            label: '알림 설정',
            subtitle: '카테고리별 푸시 on/off',
            onTap: () => Navigator.of(
              context,
            ).push(slideRoute(const NotificationSettingsScreen())),
          ),
          _SettingsRow(
            icon: Symbols.shield_person,
            label: '개인정보 처리방침',
            subtitle: '본 앱이 처리하는 정보와 처리 방식',
            onTap: () => Navigator.of(
              context,
            ).push(slideRoute(const PrivacyPolicyScreen())),
          ),
          if (user != null)
            _SettingsRow(
              icon: Symbols.person_remove,
              label: '친구·시간표 공유 사용 중지',
              subtitle: '자체 서버 저장 데이터 즉시 삭제',
              destructive: true,
              onTap: () => _onWithdrawTap(context, ref),
            ),
          if (user != null)
            _SettingsRow(
              icon: Symbols.logout,
              label: '로그아웃',
              subtitle: '${user.username} · ${user.userId}',
              destructive: true,
              onTap: () => _onLogoutTap(context, ref),
            ),
        ],
      ),
    );
  }

  /// 친구·시간표 공유 사용 중지 — 자체 서버 데이터 즉시 영구 삭제.
  Future<void> _onWithdrawTap(BuildContext context, WidgetRef ref) async {
    final onboarding = ref.read(supabaseOnboardingProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('친구·시간표 공유 사용 중지'),
        content: const Text(
          '친구 관계, 공유된 시간표, 시설예약 캐시 등 자체 서버에 저장된 데이터가 즉시 영구 삭제됩니다.\n'
          '학생증·학사·성적 등 다른 기능은 그대로 이용할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('사용 중지'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await onboarding.withdraw();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('친구·시간표 공유 사용을 중지했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용 중지에 실패했어요. 잠시 후 다시 시도해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onLogoutTap(BuildContext context, WidgetRef ref) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final authNotifier = ref.read(authStateProvider.notifier);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text(
          '로그아웃하면 자동 로그인 정보와 UCheck 자격증명이 모두 삭제됩니다.\n'
          '다음 진입 시 학번과 비밀번호를 다시 입력해야 합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await authNotifier.logout();
    // 설정 화면 등 sub-route를 모두 정리하고 AuthGate(LoginScreen)만 노출.
    if (rootNavigator.mounted) {
      rootNavigator.popUntil((r) => r.isFirst);
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
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
    final accent = destructive ? Colors.red.shade700 : AppColors.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: destructive ? accent : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right,
                size: 18,
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
