import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/official_brand_logo.dart';

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
        backgroundColor: AppColors.primary,
        body: Stack(
          children: [
            const Positioned.fill(child: _OfficialCampusBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 62
                            ? constraints.maxHeight - 62
                            : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _OfficialHeroBrand(),
                          const SizedBox(height: 58),
                          _UpdatePanel(
                            title: title ?? '새 버전 설치가 필요합니다',
                            message:
                                message ??
                                '안정적인 세종대역 서비스를 위해 최신 버전으로 업데이트해 주세요.',
                            onUpdate: _openStore,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '© Sejong University',
                            textAlign: TextAlign.center,
                            style: AppTypography.labelMd.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _OfficialCampusBackground extends StatelessWidget {
  const _OfficialCampusBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_campus_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.66),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.58),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: -86,
            child: Opacity(
              opacity: 0.18,
              child: OfficialBrandLogo(
                width: 360,
                height: 360,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialHeroBrand extends StatelessWidget {
  const _OfficialHeroBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 66,
          height: 66,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const OfficialBrandLogo(),
        ),
        const SizedBox(height: 20),
        Text(
          'Sejong Univ\nStation',
          style: AppTypography.headlineLg.copyWith(
            color: Colors.white,
            fontSize: 40,
            height: 1.06,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
          ),
          child: Text(
            '세종대역 · 세종대 모바일 학생 서비스',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMd.copyWith(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdatePanel extends StatelessWidget {
  const _UpdatePanel({
    required this.title,
    required this.message,
    required this.onUpdate,
  });

  final String title;
  final String message;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.system_update_alt,
                  color: AppColors.primary,
                  size: 26,
                  fill: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '필수 업데이트',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: AppTypography.headlineMd.copyWith(
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onUpdate,
            child: Container(
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.26),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Symbols.open_in_new,
                    color: Colors.white,
                    size: 22,
                    weight: 600,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '스토어에서 업데이트',
                    style: AppTypography.labelMd.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
