import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_config.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_recommendation.dart';

Future<RecommendedUpdateDialogAction?> showRecommendedUpdateDialog(
  BuildContext context, {
  required AppUpdateConfig config,
}) {
  return showDialog<RecommendedUpdateDialogAction>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (ctx) => _RecommendedUpdateDialog(config: config),
  );
}

class _RecommendedUpdateDialog extends StatelessWidget {
  const _RecommendedUpdateDialog({required this.config});

  final AppUpdateConfig config;

  @override
  Widget build(BuildContext context) {
    final title = config.recommendTitle ?? '새로운 버전이 출시되었어요.';
    final message =
        config.recommendMessage ?? '더 안정적인 사용을 위해 최신 버전으로 업데이트해 주세요.';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.16),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(
                    Symbols.system_update_alt,
                    fill: 1,
                    size: 29,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMd.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
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
                _DialogButton(
                  label: '업데이트하러가기',
                  filled: true,
                  leading: Symbols.open_in_new,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(RecommendedUpdateDialogAction.update),
                ),
                const SizedBox(height: 10),
                _DialogButton(
                  label: '하루 동안 보지 않기',
                  filled: false,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(RecommendedUpdateDialogAction.snoozeDay),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(
                  context,
                ).pop(RecommendedUpdateDialogAction.close),
                icon: const Icon(Symbols.close, size: 22),
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppColors.onPrimary : AppColors.onSurface;
    return Material(
      color: filled ? AppColors.primary : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(leading, size: 19, color: foreground, weight: 600),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
