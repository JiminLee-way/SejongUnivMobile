import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/features/home/presentation/widgets/event_card_view.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notice_detail_screen.dart';

class EventCarousel extends StatefulWidget {
  const EventCarousel({super.key, required this.events});

  final List<EventCard> events;

  static const Duration slideInterval = Duration(milliseconds: 4500);
  static const Duration slideAnimation = Duration(milliseconds: 400);

  @override
  State<EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<EventCarousel> {
  late final PageController _controller;
  Timer? _autoTimer;
  int _current = 0;
  bool _paused = false;
  bool _animatingProgrammatically = false;

  bool get _hasMultiplePages => widget.events.length > 1;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (_hasMultiplePages) _startTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _autoTimer?.cancel();
    if (!_hasMultiplePages || _paused) return;
    _autoTimer = Timer.periodic(EventCarousel.slideInterval, (_) {
      if (!mounted) return;
      _goTo(_current + 1, byUser: false);
    });
  }

  Future<void> _goTo(int targetIndex, {required bool byUser}) async {
    if (!_controller.hasClients) return;
    final n = widget.events.length;
    final next = targetIndex % n;
    _animatingProgrammatically = !byUser;
    await _controller.animateToPage(
      next,
      duration: EventCarousel.slideAnimation,
      curve: Curves.easeOut,
    );
    _animatingProgrammatically = false;
  }

  void _onPageChanged(int index) {
    final wasAuto = _animatingProgrammatically;
    setState(() => _current = index);
    if (!wasAuto && !_paused) {
      // 사용자 스와이프 → 그 시점 기준 4.5초 뒤 자동 재개
      _startTimer();
    }
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _autoTimer?.cancel();
        _autoTimer = null;
      } else {
        _startTimer();
      }
    });
  }

  Future<void> _handleTap(EventCard event) async {
    switch (event.action) {
      case EventCardAction.link:
        // 외부 링크(예: YouTube) — url_launcher로 위임.
        final url = event.linkUrl;
        if (url == null || url.isEmpty) return;
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {}
      case EventCardAction.viewer:
        // 앱 내부 공지 뷰어(NoticeDetailScreen) 재활용 — body_html 렌더.
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).push(
          slideRoute(
            NoticeDetailScreen.staticDetail(
              detail: _eventToDetail(event),
              title: event.categoryLabel ?? '이벤트',
            ),
          ),
        );
    }
  }

  /// EventCard → 공지 뷰어가 쓰는 [SejongNoticeDetail]로 어댑트.
  /// imageUrl을 cover로 넘겨 뷰어 상단에 배너를 그대로 노출.
  SejongNoticeDetail _eventToDetail(EventCard e) => SejongNoticeDetail(
    id: e.id,
    title: e.title,
    categoryCode: '',
    categoryName: e.categoryLabel ?? '이벤트',
    categoryType: '',
    content: e.bodyHtml ?? '',
    imageUrl: e.imageUrl,
    writerName: e.source,
    writtenAt: e.publishedAt,
    viewCount: 0,
    attachments: const [],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.events.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, i) {
            final event = widget.events[i];
            // 카드 전체 탭 → action에 따라 내부 뷰어 / 외부 링크.
            // 내부 일시정지 버튼(InkWell)은 gesture arena에서 더 가까워 먼저 잡으므로
            // 충돌 없음.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleTap(event),
              child: EventCardView(
                event: event,
                textPanel: EventTextPanel(
                  title: event.title,
                  subtitle: event.subtitle,
                  showText: event.showText,
                  indicator: _hasMultiplePages
                      ? _PageDots(
                          count: widget.events.length,
                          current: _current,
                        )
                      : null,
                  trailing: _hasMultiplePages
                      ? _PauseButton(paused: _paused, onTap: _togglePause)
                      : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
            width: i == current ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.primary
                  : AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.paused, required this.onTap});
  final bool paused;
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
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Icon(
                paused ? Symbols.play_arrow : Symbols.pause,
                fill: 1,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
