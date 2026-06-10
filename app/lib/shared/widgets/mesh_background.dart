import 'package:flutter/material.dart';

/// Level 0 background: subtle multi-radial mesh in soft pastels.
///
/// Implemented as a Stack of three RadialGradient layers, painted once into a
/// RepaintBoundary so it never re-rasterises on scroll. Bake to a PNG asset
/// later if device profiling shows this hurts low-end Androids.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _MeshLayer()),
        child,
      ],
    );
  }
}

class _MeshLayer extends StatelessWidget {
  const _MeshLayer();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        // Cream-tinted base — pure white보다 약간 따뜻해서 글래스 톤과 어울림.
        decoration: const BoxDecoration(color: Color(0xFFFAF6F4)),
        child: Stack(
          children: [
            // 1) 크림슨 (브랜드) — 상단 좌측에서 크게 퍼짐.
            _radial(
              alignment: const Alignment(-0.4, -0.7),
              colors: const [Color(0x269E001F), Color(0x009E001F)],
              radius: 1.3,
            ),
            // 2) 따뜻한 살구/코랄 — 상단 우측. 크림슨과 보색 보조.
            _radial(
              alignment: const Alignment(0.9, -0.5),
              colors: const [Color(0x33FFB081), Color(0x00FFB081)],
              radius: 1.1,
            ),
            // 3) 페일 골드 — 좌측 중하단. 세종 골드 액센트 톤.
            _radial(
              alignment: const Alignment(-0.85, 0.4),
              colors: const [Color(0x33FFD89B), Color(0x00FFD89B)],
              radius: 1.2,
            ),
            // 4) 페일 블루/라벤더 — 하단 우측. 따뜻한 톤만 있으면 답답해서 차가운 액센트.
            _radial(
              alignment: const Alignment(0.6, 0.95),
              colors: const [Color(0x29B5C7F5), Color(0x00B5C7F5)],
              radius: 1.0,
            ),
            // 5) 부드러운 핑크 highlight — 중앙 약간 위, 전체에 통일감 더함.
            _radial(
              alignment: const Alignment(0.0, 0.1),
              colors: const [Color(0x1FFFB5C5), Color(0x00FFB5C5)],
              radius: 0.9,
            ),
          ],
        ),
      ),
    );
  }

  Widget _radial({
    required Alignment alignment,
    required List<Color> colors,
    required double radius,
  }) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: radius,
            colors: colors,
            stops: const [0.0, 0.5],
          ),
        ),
      ),
    );
  }
}
