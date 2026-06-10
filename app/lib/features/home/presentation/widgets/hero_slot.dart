import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/features/home/presentation/widgets/event_carousel.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';

/// 홈 Hero 영역.
///
/// 양면 카드 — front는 caller가 [frontBuilder]로 결정 (좌석 활성 시 SeatCard).
/// 좌석이 없으면 [frontBuilder]가 null이라 자동으로 EventCarousel만 노출하고
/// flip 버튼도 숨긴다. back은 항상 EventCarousel.
/// 높이는 폭에서 **16:9**로 도출 — 좌석(front)이 있을 때만 [height]로 바닥을 깔아
/// 두 면이 같은 높이가 되게 한다(flip 흔들림 방지). 자세한 이유는 build 참고.
class HeroSlot extends StatefulWidget {
  const HeroSlot({
    super.key,
    required this.frontBuilder,
    required this.events,
    this.height = 212,
  });

  /// null이면 좌석 없음을 의미 — EventCarousel만 노출, flip 버튼 미표시.
  final WidgetBuilder? frontBuilder;
  final List<EventCard> events;

  /// 좌석(front) 면의 **최소 높이(바닥값)**. 카드는 기본적으로 폭에서 도출한 16:9
  /// 높이를 쓰지만, 좁은 폰에서 16:9가 이보다 작아지면 좌석 콘텐츠(~210dp)가 넘치므로
  /// front가 있을 때만 이 값으로 바닥을 깐다. 좌석이 없으면 무시되고 항상 16:9.
  final double height;

  @override
  State<HeroSlot> createState() => _HeroSlotState();
}

class _HeroSlotState extends State<HeroSlot> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final hasFront = widget.frontBuilder != null;
    final canFlip = hasFront && widget.events.isNotEmpty;
    // front 없으면 항상 event를 강제 노출.
    final showEvent = hasFront ? _flipped : true;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 카드는 **항상 16:9** — 폭에서 높이를 도출한다.
        // (예전엔 높이를 212dp로 고정해 카드 비율이 화면 폭에 따라 달라졌다. 폭이 넓은
        // 폰에서 width/212 > 16:9가 되면 BoxFit.cover가 16:9 배너의 상·하단을 잘라
        // "이미지가 다 안 나오던" 버그의 원인.)
        //
        // 단, 좌석 카드(front)는 콘텐츠가 ~210dp라 좁은 폰의 16:9 높이(예: 360dp→175dp)
        // 로는 넘친다. 그래서 **front가 있을 때만** [widget.height](좌석 최소 높이)로
        // 바닥을 깐다 — 두 면이 같은 높이라 flip 시 흔들리지 않는다. 좌석이 없으면
        // (대부분의 경우, 그리고 이 버그가 보고된 케이스) 모든 폰에서 정확히 16:9.
        final aspectHeight = constraints.maxWidth * 9 / 16;
        final slotHeight = hasFront && aspectHeight < widget.height
            ? widget.height
            : aspectHeight;

        final Widget body = SizedBox(
          key: ValueKey(showEvent ? 'event' : 'front'),
          height: slotHeight,
          child: showEvent
              ? GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: AppRadius.xl,
                  child: EventCarousel(events: widget.events),
                )
              : widget.frontBuilder!(context),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: _flipTransition,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              ),
              child: body,
            ),
            if (canFlip)
              // "다음 강의 …" 라인(LectureContextRow, ~16dp 높이, 카드 top
              // padding 22dp 아래 시작)의 중심선과 flip 버튼(36dp) 중심을 정렬:
              //   row 중심 = 22 + 16/2 = 30dp → button top = 30 - 36/2 = 12dp.
              Positioned(
                top: 12,
                right: 22,
                child: _FlipButton(
                  flipped: _flipped,
                  onTap: () => setState(() => _flipped = !_flipped),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _flipTransition(Widget child, Animation<double> animation) {
    // front 없으면 강제 event 노출 — _flipped와 무관하게 showEventNow=true.
    final showEventNow = widget.frontBuilder == null || _flipped;
    final isIncoming =
        (child.key == const ValueKey('event') && showEventNow) ||
        (child.key == const ValueKey('front') && !showEventNow);
    // incoming은 90→0, outgoing은 0→-90 (Y축).
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        final t = animation.value;
        final angle = isIncoming
            ? (1 - t) *
                  1.5708 // 90° → 0
            : -t * 1.5708; // 0 → -90°
        final visible = isIncoming ? t > 0.5 : t < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: Opacity(opacity: visible ? 1 : 0, child: c),
        );
      },
      child: child,
    );
  }
}

class _FlipButton extends StatelessWidget {
  const _FlipButton({required this.flipped, required this.onTap});
  final bool flipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A2D3133),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              // UNO reverse 스타일 — 두 곡선 화살표가 서로 반대 방향.
              child: Transform.rotate(
                angle: flipped ? 3.14159 : 0,
                child: const Icon(
                  Symbols.autorenew,
                  fill: 1,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
