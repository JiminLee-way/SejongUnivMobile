import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

/// 열람실 좌석맵.
///
/// DOM 좌표를 사용해서 배경 이미지(`map_NN.jpg`)의 책상 위에 좌석을
/// 픽셀 단위로 정렬한다.
/// `InteractiveViewer`로 핀치줌/팬, 초기엔 fit-to-width로 자동 배치.
class SeatMap extends StatefulWidget {
  const SeatMap({
    super.key,
    required this.layout,
    required this.statuses,
    this.selectedSeatId,
    this.onSeatTap,
  });

  final RoomLayout layout;
  final SeatStatusMap statuses;
  final int? selectedSeatId;
  final ValueChanged<int>? onSeatTap;

  @override
  State<SeatMap> createState() => _SeatMapState();
}

class _SeatMapState extends State<SeatMap> {
  final TransformationController _controller = TransformationController();
  bool _initialized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 초기 변환: bbox 가운데를 viewport 가운데에 놓되 fit-to-width의 1.5×로
  /// 좌석 번호를 읽기 좋게 확대해서 시작. 사용자는 pinch-out으로 minScale
  /// (fit-to-width)까지 축소 가능.
  void _applyInitialTransform(BoxConstraints c) {
    final canvas = widget.layout;
    final bbox = canvas.bbox;
    final paddedBboxW = bbox.width * 1.08;
    final fitScale = c.maxWidth / paddedBboxW;
    final minScale = (c.maxWidth / canvas.canvasWidth) * 0.9;
    const maxScale = 3.5;
    // 초기 배율: fit의 1.5배 — 사용자 요청. clamp로 범위 보호.
    final initial = (fitScale * 1.5).clamp(minScale, maxScale);
    // bbox 중심이 viewport 중심에 오도록 translate (수평), 위쪽 마진 24.
    final bboxCenterX = bbox.left + bbox.width / 2;
    final tx = c.maxWidth / 2 - bboxCenterX * initial;
    final ty = -bbox.top * initial + 24;
    _controller.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(initial, initial, initial, 1);
  }

  @override
  Widget build(BuildContext context) {
    final canvas = widget.layout;
    return LayoutBuilder(
      builder: (context, c) {
        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyInitialTransform(c);
          });
        }
        // fit-to-width minScale (전체 가로) — 더 줄어들지 않게.
        final minScale = (c.maxWidth / canvas.canvasWidth) * 0.9;
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: minScale,
            maxScale: 3.5,
            boundaryMargin: EdgeInsets.symmetric(
              horizontal: c.maxWidth * 0.3,
              vertical: c.maxHeight * 0.3,
            ),
            child: SizedBox(
              width: canvas.canvasWidth,
              height: canvas.canvasHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      canvas.backgroundAsset,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  for (final s in canvas.seats)
                    // 원본 td 영역(35×41)에는 desk.png(35×36) + 의자 그림자
                    // 가 포함돼 있어, 색칠 박스 그대로 그리면 책상보다 살짝
                    // 아래로 보임. 모든 좌석 위로 4px 보정해서 책상 그림 중심에
                    // 정렬.
                    Positioned(
                      left: s.x,
                      top: s.y - 4,
                      width: s.w,
                      height: s.h,
                      child: _SeatTile(
                        seat: s,
                        status: widget.statuses[s.id] ?? SeatStatus.unavailable,
                        selected: widget.selectedSeatId == s.id,
                        onTap: widget.onSeatTap == null
                            ? null
                            : () => widget.onSeatTap!(s.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.status,
    required this.selected,
    this.onTap,
  });

  final SeatPosition seat;
  final SeatStatus status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    // 좌석 자체는 원본 도면의 책상 모양에 맞춰 둥근 사각.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 선택 시 글로우.
          if (selected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: seatSelectedRing.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          // 좌석 박스.
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
              border: selected
                  ? Border.all(color: seatSelectedRing, width: 2.5)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 0.8,
                    ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 1.5,
                  offset: Offset(0, 0.5),
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    '${seat.id}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 좌석 상태 범례 (legend) — 헤더 카드 아래 줄.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 10 : 14,
      runSpacing: 6,
      children: [
        for (final s in SeatStatus.values)
          _LegendChip(status: s, compact: compact),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.status, required this.compact});

  final SeatStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dotSize = compact ? 10.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: status.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status.label,
          style: (compact ? AppTypography.labelSm : AppTypography.labelMd)
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 헤더 — 열람실 이름 + 사용 카운터 게이지 + 범례.
class RoomHeader extends StatelessWidget {
  const RoomHeader({
    super.key,
    required this.name,
    required this.occupied,
    required this.total,
  });

  final String name;
  final int occupied;
  final int total;

  @override
  Widget build(BuildContext context) {
    final available = total - occupied;
    final ratio = total == 0 ? 0.0 : occupied / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Symbols.local_library,
              size: 22,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                style: AppTypography.headlineMd.copyWith(fontSize: 14),
                children: [
                  TextSpan(
                    text: '$available',
                    style: TextStyle(
                      color: SeatStatus.available.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                  TextSpan(
                    text: ' 자리 비어있음',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '$occupied / $total',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: AppColors.surfaceContainerHigh),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio.clamp(0.0, 1.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.surfaceTint],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SeatLegend(compact: true),
      ],
    );
  }
}
