import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_list_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

/// 홈 "실시간 열람실 현황" — 한 페이지에 3행(제1/2/3 열람실).
///
/// 좌우 수동 스와이프로 다음 페이지(제4/5/6 열람실). 자동 슬라이드 없음.
/// libseat은 A/B로 분리된 열람실(예: 제1열람실A + 제1열람실B)을 보내지만 홈에서는
/// 합쳐서 6개로 표시 (사용자가 한 눈에 "1/2/3"과 "4/5/6"으로 보고 싶다는 요청).
/// 카드 탭 → LibraryListScreen으로 진입 (A/B 둘 다 보임).
class LibraryStatusStrip extends ConsumerStatefulWidget {
  const LibraryStatusStrip({super.key});

  @override
  ConsumerState<LibraryStatusStrip> createState() => _LibraryStatusStripState();
}

class _LibraryStatusStripState extends ConsumerState<LibraryStatusStrip> {
  static const _rowsPerPage = 3;
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomListProvider);
    return GlassCard(
      borderRadius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.local_library,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '실시간 열람실 현황',
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutterMobile),
          rooms.when(
            loading: () => const _LoaderBox(),
            error: (_, _) => const _ErrorBox(),
            data: (list) {
              final merged = _mergeABRooms(list);
              if (merged.isEmpty) return const _EmptyBox();
              final pages = _chunk(merged, _rowsPerPage);
              return _Pager(
                pages: pages,
                pageCtrl: _pageCtrl,
                currentPage: _page,
                onPageChanged: (p) => setState(() => _page = p),
              );
            },
          ),
        ],
      ),
    );
  }

  /// `제1열람실A` + `제1열람실B`를 한 카드로 합산. base name(끝 영문 한 글자
  /// 제거) 기준 그룹핑 + used/total 합. 첫 등장 순서 유지.
  static List<ReadingRoom> _mergeABRooms(List<ReadingRoom> list) {
    final order = <String>[];
    final byBase = <String, List<ReadingRoom>>{};
    for (final r in list) {
      final base = r.name.replaceAll(RegExp(r'[A-Za-z]\s*$'), '').trim();
      if (!byBase.containsKey(base)) order.add(base);
      byBase.putIfAbsent(base, () => []).add(r);
    }
    return [
      for (final base in order)
        ReadingRoom(
          roomNo: byBase[base]!.first.roomNo,
          name: base,
          used: byBase[base]!.fold(0, (s, r) => s + r.used),
          total: byBase[base]!.fold(0, (s, r) => s + r.total),
        ),
    ];
  }

  static List<List<ReadingRoom>> _chunk(List<ReadingRoom> list, int size) {
    final out = <List<ReadingRoom>>[];
    for (var i = 0; i < list.length; i += size) {
      out.add(list.sublist(i, (i + size).clamp(0, list.length)));
    }
    return out;
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.pages,
    required this.pageCtrl,
    required this.currentPage,
    required this.onPageChanged,
  });

  final List<List<ReadingRoom>> pages;
  final PageController pageCtrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  static const _rowH = 38.0;
  static const _rowGap = 16.0;
  static const _rowsPerPage = 3;

  @override
  Widget build(BuildContext context) {
    final height = _rowH * _rowsPerPage + _rowGap * (_rowsPerPage - 1);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: pageCtrl,
            physics: const BouncingScrollPhysics(),
            itemCount: pages.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => _Page(rooms: pages[i]),
          ),
        ),
        if (pages.length > 1) ...[
          const SizedBox(height: 12),
          _Dots(count: pages.length, current: currentPage),
        ],
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.rooms});
  final List<ReadingRoom> rooms;

  @override
  Widget build(BuildContext context) {
    // 좌우 padding으로 swipe 중간 frame에서 다음/이전 페이지의 텍스트가 옆에
    // 붙어 보이는 현상 방지 (예: "19 / 189제4열람실"로 숫자+이름 충돌).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rooms.length; i++) ...[
            _RoomRow(room: rooms[i]),
            if (i != rooms.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// 한 줄짜리 행 — 라벨 + (사용 중 / 전체) + brand red 그라데이션 progress bar.
/// 탭 시 LibraryListScreen으로 진입.
class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room});
  final ReadingRoom room;

  @override
  Widget build(BuildContext context) {
    final ratio = room.usageRatio;
    // 매우 낮은 사용률이어도 막대가 보이도록 최소 4% 너비 보장 — 시각 보조.
    final visibleRatio = ratio < 0.04 && ratio > 0 ? 0.04 : ratio;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(slideRoute(const LibraryListScreen())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    room.name,
                    style: AppTypography.labelMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: '${room.used}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' / ${room.total}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: visibleRatio.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.surfaceTint],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.primary
                  : AppColors.outline.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          if (i != count - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

/// 로딩 — 열람실 이름(제1~3열람실)은 고정 표시, 카운트·게이지바만 shimmer.
/// 실제 [_Pager] 의 row layout(_rowH=38, _rowGap=16)을 그대로 모사해 데이터가
/// 도착할 때 카드 높이가 깜빡이지 않도록 한다.
/// 텍스트는 [Shimmer] 바깥에 두고 shimmer는 회색 박스에만 적용 — 이름은 fix.
class _LoaderBox extends StatelessWidget {
  const _LoaderBox();

  static const _names = ['제1열람실', '제2열람실', '제3열람실'];
  static const _rowH = 38.0;
  static const _rowGap = 16.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowH * 3 + _rowGap * 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _names.length; i++) ...[
              _SkeletonRow(name: _names[i]),
              if (i != _names.length - 1) const SizedBox(height: _rowGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                name,
                style: AppTypography.labelMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Shimmer(child: ShimmerBox(width: 48, height: 11)),
          ],
        ),
        const SizedBox(height: 6),
        const Shimmer(child: ShimmerBox(height: 8, radius: AppRadius.full)),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 130,
    child: Center(
      child: Text(
        '열람실 정보를 불러오지 못했어요',
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 130,
    child: Center(
      child: Text(
        '열람실 정보가 없어요',
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
