import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/home_widgets/domain/entities/home_widget_models.dart';
import 'package:sejong_smart_campus/features/home_widgets/presentation/providers/home_widgets_providers.dart';

/// 홈 상단 배너 5개 — sjapp의 메인 슬라이드 미러.
///
/// 자동 슬라이드 8초 간격. 외부 링크는 url_launcher로 위임.
class HomeBannersCarousel extends ConsumerStatefulWidget {
  const HomeBannersCarousel({super.key});

  @override
  ConsumerState<HomeBannersCarousel> createState() =>
      _HomeBannersCarouselState();
}

class _HomeBannersCarouselState extends ConsumerState<HomeBannersCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _autoTimer;
  int _index = 0;

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAuto(int count) {
    _autoTimer?.cancel();
    if (count <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final next = (_index + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homeBannersProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        _startAuto(banners.length);
        return Column(
          children: [
            SizedBox(
              height: 132,
              child: PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _BannerCard(banner: banners[i]),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});
  final HomeBanner banner;

  Future<void> _launch() async {
    if (banner.linkUrl.isEmpty) return;
    try {
      await launchUrl(
        Uri.parse(banner.linkUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _launch,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.85),
                  AppColors.primaryContainer.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        banner.altText,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner.plainTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (banner.imageUrl.isNotEmpty)
                  ClipOval(
                    child: Container(
                      width: 64,
                      height: 64,
                      color: Colors.white.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        banner.imageUrl,
                        fit: BoxFit.contain,
                        // 네트워크 실패 시 silent — 빈 원으로 fallback.
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
