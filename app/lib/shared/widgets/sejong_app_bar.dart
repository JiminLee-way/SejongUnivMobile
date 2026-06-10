import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

class SejongAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SejongAppBar({
    super.key,
    this.remainingLectures = 0,
    this.onLecturesTap,
    this.onSearchTap,
    this.onNotificationTap,
    this.hasNotification = true,
  });

  final int remainingLectures;
  final VoidCallback? onLecturesTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;
  final bool hasNotification;

  static const _height = 64.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    // Fake glass — 진짜 BackdropFilter(blur)는 ListView 스크롤 시 아래 컨텐츠
    // 변화로 매 프레임 saveLayer + Gaussian blur 재계산이 일어나 풀폭 64+top dp
    // 영역에서 GPU stall이 발생한다(GlassCard가 동일 이유로 이미 제거한 패턴).
    // 표면을 살짝 더 짙게(0.92~0.78) + 살짝 더 강한 hairline + RepaintBoundary로
    // 정적 raster cache → 시각적으로는 차이 미세, 스크롤 FPS 결정적 회복.
    final top = MediaQuery.paddingOf(context).top;
    return RepaintBoundary(
      child: Container(
        height: _height + top,
        padding: EdgeInsets.only(top: top),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface.withValues(alpha: 0.97),
              AppColors.surface.withValues(alpha: 0.92),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.6),
              width: 0.6,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Row(
            children: [
              Expanded(
                child: _LecturesIndicator(
                  remainingLectures: remainingLectures,
                  onTap: onLecturesTap,
                ),
              ),
              _IconButton(icon: Symbols.search, onTap: onSearchTap),
              const SizedBox(width: 4),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _IconButton(
                    icon: Symbols.notifications,
                    onTap: onNotificationTap,
                  ),
                  if (hasNotification)
                    const Positioned(right: 6, top: 6, child: _Dot()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LecturesIndicator extends StatelessWidget {
  const _LecturesIndicator({required this.remainingLectures, this.onTap});

  final int remainingLectures;
  final VoidCallback? onTap;

  String get _label =>
      remainingLectures > 0 ? '남은 강의 $remainingLectures개' : '남은 강의 없음';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A2D3133),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Symbols.event_note,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _label,
                    style: AppTypography.headlineMd.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Symbols.chevron_right,
                  size: 18,
                  color: AppColors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 24, color: AppColors.secondary),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
    );
  }
}
