import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/shell/presentation/widgets/bottom_nav_insets.dart';

/// 앱 전역 토스트 — **루트 Overlay**에 띄워 바텀 네비/드로어 위에 항상 보이게 한다.
///
/// `ScaffoldMessenger`는 SnackBar를 (중첩 Scaffold 중) **루트 Scaffold 하나에만**
/// 띄운다(`scaffold.dart` `_isRoot`). 이 앱의 루트 Scaffold는 AppShell이고,
/// AppShell의 커스텀 바텀 네비(≈92px, 본문 Stack 안에 그려짐)와 endDrawer가
/// 화면 하단을 덮는다. 그래서 **커뮤니티 탭(뉴스/게시판)이나 전체서비스 드로어
/// (동아리/연구실/청원)에서 띄운 "준비 중" SnackBar는 네비/드로어 뒤로 가려져
/// 사용자에게 안 보였다.** 루트 Overlay 엔트리는 모든 route 콘텐츠 위에 그려져
/// 바텀 네비·드로어가 가리지 못하므로 어떤 화면에서 띄워도 보인다.
///
/// 사용자 탭에 동기적으로 호출되는 전제라(딜레이 갭 없음) context는 항상 유효.
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.lightImpact();

  // 바텀 네비 위로 띄우기 위한 하단 여백. AppShell 안(탭/드로어)이면 측정된 nav
  // 높이를, 밖(풀스크린 push)이면 safe-area bottom을 기준으로 한다.
  final navInset = BottomNavInsets.readNotListen(context);
  final bottomSafe = MediaQuery.maybeOf(context)?.padding.bottom ?? 0;
  final bottomGap = (navInset > 0 ? navInset : bottomSafe) + 16;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastView(
      message: message,
      bottomGap: bottomGap,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.bottomGap,
    required this.onDone,
  });

  final String message;
  final double bottomGap;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  late final Animation<double> _slide = Tween<double>(
    begin: 8,
    end: 0,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 1900), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: widget.bottomGap,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: child,
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.onSurface.withValues(alpha: 0.93),
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppTypography.labelMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
