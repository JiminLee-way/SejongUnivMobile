import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

/// 앱 디자인 시스템(크림슨 + Pretendard + 라운드 글래스)에 맞춘 다이얼로그.
///
/// native `AlertDialog`(기본 폰트/회색 텍스트 버튼)를 대체 — 아이콘 배지 + 굵은
/// 제목 + 본문 + 꽉 찬 액션 버튼으로 OneUI 톤. 확인형([showSejongConfirmDialog])과
/// 결과형([showSejongResultDialog]) 두 가지.

/// 확인 다이얼로그 — `true`(확인) / `false`(취소/배경탭)를 반환.
Future<bool> showSejongConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  IconData icon = Symbols.help,
  Color accent = AppColors.primary,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (ctx) => _SejongDialog(
      icon: icon,
      accent: accent,
      title: title,
      message: message,
      actions: [
        Expanded(
          child: _DialogButton(
            label: cancelLabel,
            filled: false,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DialogButton(
            label: confirmLabel,
            filled: true,
            accent: accent,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 결과 알림 — 확인 버튼 하나. [success]에 따라 아이콘만 달라짐.
Future<void> showSejongResultDialog(
  BuildContext context, {
  required bool success,
  required String title,
  required String message,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (ctx) => _SejongDialog(
      icon: success ? Symbols.check_circle : Symbols.info,
      iconFill: true,
      accent: AppColors.primary,
      title: title,
      message: message,
      actions: [
        Expanded(
          child: _DialogButton(
            label: '확인',
            filled: true,
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ),
      ],
    ),
  );
}

class _SejongDialog extends StatelessWidget {
  const _SejongDialog({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.actions,
    this.iconFill = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool iconFill;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            const BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘 배지 — accent 그라데이션 틴트.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.16),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Icon(
                icon,
                fill: iconFill ? 1 : 0,
                size: 28,
                color: accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMd.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? accent : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: filled ? AppColors.onPrimary : AppColors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
