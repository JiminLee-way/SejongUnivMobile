import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

/// 강제 업데이트 — 닫기 불가 전체 화면. 스토어로 가는 것 외 탈출구가 없다.
///
/// [AppUpdateGate]가 `forced` 판정 시 루트 네비게이터에 `pushAndRemoveUntil`로
/// 띄운다(스택 전체 제거 → 어떤 화면 위에서도 확실히 덮음). `PopScope(canPop:false)`
/// 로 안드로이드 백키도 무력화.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.storeUrl,
    this.title,
    this.message,
  });

  /// 서버 구동 스토어 URL. 비어 있으면 버튼은 무동작(안전).
  final String storeUrl;
  final String? title;
  final String? message;

  Future<void> _openStore() async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Symbols.system_update,
                  size: 64,
                  color: AppColors.primary,
                  fill: 1,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                Text(
                  title ?? '업데이트가 필요해요',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMd,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  message ??
                      '원활한 사용을 위해 최신 버전으로 업데이트해 주세요.\n'
                          '계속하려면 업데이트가 필요합니다.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                FilledButton(
                  onPressed: _openStore,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    '지금 업데이트',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
