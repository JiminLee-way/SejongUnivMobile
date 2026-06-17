import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

class SejongBottomNav extends StatelessWidget {
  /// 바텀 nav가 body 영역 안에서 차지하는 시각 높이.
  ///
  /// 내부 구성: padding top(8) + button content(아이콘 24 + gap 2 + label 14
  /// + 버튼 vertical padding 12) + padding bottom(8) ≈ 68dp.
  ///
  /// AppShell의 Scaffold는 `extendBody=false`라 body가 이미 safe area를
  /// 제외하므로, 이 위에 floating bar를 띄울 때는 safe inset을 별도로 더하지
  /// 말 것 — `bottom: SejongBottomNav.approxHeight`만으로 정확히 nav 위에
  /// 붙는다.
  static const double approxHeight = 68;

  const SejongBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  // U-Check와 커뮤니티성 기능은 메인 화면의 바로가기 / 알림 tap /
  // 전체 서비스에서 push 형태로 진입. 하단 세 번째 탭은 실 API 공지 목록 전용.
  static const _items = <_NavItem>[
    _NavItem('메인', Symbols.home),
    _NavItem('학생증', Symbols.badge),
    _NavItem('공지', Symbols.campaign),
    _NavItem('전체', Symbols.menu),
  ];

  @override
  Widget build(BuildContext context) {
    // Fake glass — 진짜 BackdropFilter(blur) 는 콘텐츠 스크롤마다 풀폭 × 76dp
    // 영역을 Gaussian blur 재계산해 GPU stall이 발생한다. 표면을 살짝 더 짙게
    // (0.78 → 0.96) + 정적 RepaintBoundary raster cache로 시각 차이는 미세,
    // 스크롤 FPS는 결정적으로 회복. mesh 배경이 부드러운 색 블록이라 blur가
    // 없어도 경계 위화감이 적음.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surface.withValues(alpha: 0.93),
                AppColors.surface.withValues(alpha: 0.98),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.65),
                width: 0.6,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ambientShadow,
                blurRadius: 14,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 8,
            bottom: 8 + MediaQuery.paddingOf(context).bottom,
            left: 8,
            right: 8,
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    heightFactor: 1.0,
                    child: _NavButton(
                      item: _items[i],
                      selected: currentIndex == i,
                      onTap: () => onTap(i),
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

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _pressed;
    final color = highlighted ? AppColors.primary : AppColors.secondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.item.icon,
                size: 24,
                fill: widget.selected ? 1 : 0,
                color: color,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 10,
                    color: color,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
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
