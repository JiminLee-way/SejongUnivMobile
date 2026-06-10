import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/community/data/datasources/mock_community.dart';
import 'package:sejong_smart_campus/features/community/domain/entities/community_models.dart';
import 'package:sejong_smart_campus/shared/utils/format.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/app_toast.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';

/// 커뮤니티 탭 — 세 가지 콘텐츠 소스를 하나의 글래스 화면에 묶음.
///
/// 1) 공지   — 학사 7개 카테고리 (general/admission/academic/exchange*/career/scholarship)
/// 2) 뉴스   — 준비 중
/// 3) 게시판 — 자체 커뮤니티 (고파스/에브리타임 스타일)
///
/// 상단 세그먼트 컨트롤로 세 영역을 평행 전환. 깊이감을 위해 글래스 캡슐 +
/// 선택 인디케이터 슬라이드 애니메이션 사용.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _segment = 0; // 0: 공지, 1: 뉴스, 2: 게시판
  NoticeCategory? _noticeFilter; // null이면 전체

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  /// 공지(0)만 사용 가능. 뉴스(1)·게시판(2)은 탭 즉시 "준비 중" 안내만 띄우고
  /// 세그먼트는 전환하지 않는다(공지 외 콘텐츠 미노출).
  void _onSegmentTap(int i) {
    if (i == 0) {
      setState(() => _segment = 0);
      return;
    }
    // 안내는 루트 Overlay 토스트로 띄운다. 기존 SnackBar는 ScaffoldMessenger가
    // 루트 Scaffold(AppShell) 하단에만 띄워서, 커뮤니티 탭 위에 고정된 커스텀
    // 바텀 네비(≈92px) 뒤로 가려져 사용자에게 안 보였다. [showAppToast] 참고.
    final label = i == 1 ? '뉴스' : '게시판';
    showAppToast(context, '$label은(는) 아직 준비 중이에요');
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: SejongRefresh(
              onRefresh: _onRefresh,
              topInset: topPad + 64,
              child: ListView(
                padding: EdgeInsets.only(
                  top: topPad + 64 + 20,
                  left: AppSpacing.marginMobile,
                  right: AppSpacing.marginMobile,
                  bottom: 112 + botPad,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  _SegmentBar(index: _segment, onChanged: _onSegmentTap),
                  const SizedBox(height: AppSpacing.stackMd),
                  switch (_segment) {
                    0 => _NoticeSection(
                      filter: _noticeFilter,
                      onFilterChanged: (c) => setState(() => _noticeFilter = c),
                    ),
                    1 => const _NewsSection(),
                    _ => const _BoardSection(),
                  },
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.topCenter,
            child: _CommunityAppBar(),
          ),
        ],
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  AppBar                                                                  ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class _CommunityAppBar extends StatelessWidget {
  const _CommunityAppBar();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      height: 64 + topPad,
      padding: EdgeInsets.only(top: topPad),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ambientShadow,
            blurRadius: 18,
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
              child: Text(
                '커뮤니티',
                style: AppTypography.headlineMd.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            _AppBarIconButton(icon: Symbols.search, onTap: () {}),
            const SizedBox(width: 4),
            _AppBarIconButton(icon: Symbols.edit_square, onTap: () {}),
          ],
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 24, color: AppColors.secondary),
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  Segment Bar — Glass capsule with sliding indicator                      ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['공지', '뉴스', '게시판'];
  static const _icons = [Symbols.campaign, Symbols.newspaper, Symbols.forum];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / 3;
        return Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ambientShadow,
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: segmentWidth * index,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: AppTypography.labelMd.copyWith(
                                color: i == index
                                    ? AppColors.onPrimary
                                    : AppColors.onSurfaceVariant,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    _icons[i],
                                    size: 16,
                                    fill: i == index ? 1 : 0,
                                    color: i == index
                                        ? AppColors.onPrimary
                                        : AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(_labels[i]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  Section 1 — 공지                                                         ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class _NoticeSection extends StatelessWidget {
  const _NoticeSection({required this.filter, required this.onFilterChanged});
  final NoticeCategory? filter;
  final ValueChanged<NoticeCategory?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final items = filter == null
        ? mockNotices
        : mockNotices.where((n) => n.category == filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NoticeFilterChips(selected: filter, onChanged: onFilterChanged),
        const SizedBox(height: AppSpacing.stackMd),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _NoticeRow(item: items[i]),
                if (i < items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x1A5C403F),
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(
                        Symbols.inbox,
                        size: 40,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '해당 카테고리에 공지가 없어요',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeFilterChips extends StatelessWidget {
  const _NoticeFilterChips({required this.selected, required this.onChanged});
  final NoticeCategory? selected;
  final ValueChanged<NoticeCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _Chip(
            label: '전체',
            selected: selected == null,
            color: AppColors.primary,
            onTap: () => onChanged(null),
          ),
          for (final c in NoticeCategory.values) ...[
            const SizedBox(width: 8),
            _Chip(
              label: c.label,
              selected: selected == c,
              color: c.color,
              onTap: () => onChanged(c),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? color : Colors.white.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: selected
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.item});
  final NoticeItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1행: 카테고리 라벨 (색상으로 식별) + 핀/첨부 아이콘
              Row(
                children: [
                  Text(
                    item.category.label,
                    style: AppTypography.labelSm.copyWith(
                      color: item.category.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      height: 1.0,
                    ),
                  ),
                  if (item.isPinned) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Symbols.push_pin,
                      size: 12,
                      fill: 1,
                      color: AppColors.primary,
                    ),
                  ],
                  const Spacer(),
                  if (item.hasAttachment)
                    Icon(
                      Symbols.attach_file,
                      size: 13,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // 2행: 제목
              Text(
                item.title,
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 3행: 게시처 · 시간 · 조회수
              Row(
                children: [
                  Text(
                    item.publisher,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    relativeTime(item.publishedAt),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Symbols.visibility,
                    size: 12,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    compactCount(item.viewCount),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  Section 2 — 뉴스                                                         ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class _NewsSection extends StatelessWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤드라인 — 첫번째 뉴스를 큰 카드로
        _HeadlineNewsCard(item: mockNews.first),
        const SizedBox(height: AppSpacing.stackMd),
        _MutedSectionLabel(icon: Symbols.feed, label: '최근 뉴스', tail: '준비 중'),
        const SizedBox(height: 12),
        for (var i = 1; i < mockNews.length; i++) ...[
          _NewsRowCard(item: mockNews[i]),
          if (i < mockNews.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HeadlineNewsCard extends StatelessWidget {
  const _HeadlineNewsCard({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              child: _NewsThumb(seed: item.thumbnailSeed, tag: item.tag),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  item.summary,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.55,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Symbols.schedule,
                      size: 14,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      relativeTime(item.publishedAt),
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '자세히 보기',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Symbols.arrow_forward,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsRowCard extends StatelessWidget {
  const _NewsRowCard({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 96,
              height: 96,
              child: _NewsThumb(seed: item.thumbnailSeed, tag: item.tag),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.summary,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  relativeTime(item.publishedAt),
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 시안용 뉴스 썸네일 — 서버에 이미지 들어오기 전까지 시드 기반 그라데이션.
class _NewsThumb extends StatelessWidget {
  const _NewsThumb({required this.seed, this.tag});
  final int seed;
  final String? tag;

  Color _accent() => Color(0xFF000000 | (seed & 0x00FFFFFF));

  @override
  Widget build(BuildContext context) {
    final base = _accent();
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withValues(alpha: 0.85),
                base.withValues(alpha: 0.55),
                AppColors.surface,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        // 장식적인 원형 블러
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -10,
          left: -10,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Center(child: Icon(Symbols.image, size: 28, color: Colors.white)),
        if (tag != null)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 0.6,
                ),
              ),
              child: Text(
                tag!,
                style: AppTypography.labelSm.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  Section 3 — 게시판                                                       ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class _BoardSection extends StatelessWidget {
  const _BoardSection();

  @override
  Widget build(BuildContext context) {
    final hot = mockBoardPosts.where((p) => p.isHot).toList();
    final recent = mockBoardPosts.where((p) => !p.isHot).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MutedSectionLabel(
          icon: Symbols.local_fire_department,
          iconFilled: true,
          iconColor: AppColors.primary,
          label: '실시간 인기',
          tail: '전체보기',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: hot.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _HotPostCard(post: hot[i], rank: i + 1),
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        _MutedSectionLabel(icon: Symbols.dashboard, label: '게시판'),
        const SizedBox(height: 12),
        const _BoardGrid(),
        const SizedBox(height: AppSpacing.stackMd),
        _MutedSectionLabel(icon: Symbols.history, label: '최근 글'),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                _BoardPostRow(post: recent[i]),
                if (i < recent.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x1A5C403F),
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HotPostCard extends StatelessWidget {
  const _HotPostCard({required this.post, required this.rank});
  final BoardPost post;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$rank',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  post.board.icon,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    post.board.label,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                post.preview,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.45,
                  letterSpacing: 0,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Symbols.favorite,
                  size: 13,
                  fill: 1,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 3),
                Text(
                  '${post.likeCount}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Symbols.chat_bubble,
                  size: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  '${post.commentCount}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                Text(
                  relativeTime(post.postedAt),
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardGrid extends StatelessWidget {
  const _BoardGrid();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: Board.values.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 4,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (_, i) => _BoardTile(board: Board.values[i]),
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.board});
  final Board board;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
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
            child: Icon(board.icon, size: 22, color: AppColors.secondary),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              board.label,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardPostRow extends StatelessWidget {
  const _BoardPostRow({required this.post});
  final BoardPost post;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          post.board.icon,
                          size: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          post.board.label,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.isAnonymous ? '익명' : post.author,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    relativeTime(post.postedAt),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                post.title,
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                post.preview,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.45,
                  letterSpacing: 0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Symbols.favorite,
                    size: 12,
                    fill: 1,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${post.likeCount}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Symbols.chat_bubble,
                    size: 12,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${post.commentCount}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  Shared bits                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class _MutedSectionLabel extends StatelessWidget {
  const _MutedSectionLabel({
    required this.icon,
    required this.label,
    this.tail,
    this.iconFilled = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? tail;
  final bool iconFilled;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          fill: iconFilled ? 1 : 0,
          color: iconColor ?? AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.headlineMd.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (tail != null)
          Text(
            tail!,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}
