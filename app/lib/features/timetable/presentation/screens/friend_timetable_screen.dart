import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_subject_palette.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friend_timetable_providers.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/timetable_providers.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/widgets/timetable_grid.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';

/// 친구의 시간표 뷰어 — 본인 시간표와 동일한 디자인 시스템(글래스 + 09–19시 그리드)
/// 을 그대로 쓰되, 친구 자신을 가리키는 헤더와 "함께 듣는 강의" 강조 배지가 추가.
///
/// 데이터는 친구가 로그인할 때 올린 시간표를 서버가 친구 관계 검증 후 복호화해
/// 내려준 실제 수강 시간표다(mock 아님). 진입 시 친구가 올린 학기 중 **가장 최근
/// 학기**를 기본 선택한다.
class FriendTimetableScreen extends ConsumerStatefulWidget {
  const FriendTimetableScreen({super.key, required this.friend});
  final Friend friend;

  @override
  ConsumerState<FriendTimetableScreen> createState() =>
      _FriendTimetableScreenState();
}

class _FriendTimetableScreenState extends ConsumerState<FriendTimetableScreen> {
  /// 사용자가 칩으로 직접 고른 학기. null이면 "친구가 올린 가장 최근 학기"를 따른다.
  Semester? _picked;

  /// 내가 같이 듣는 강의 코드 — 같은 학기 내 코드(curiNo-분반) 교집합.
  Set<String> _sharedCodes(Timetable friendTt, Semester semester) {
    final mine =
        ref.watch(timetableForSemesterProvider(semester)).value?.courses ??
        const <Course>[];
    final mineCodes = mine.map((c) => c.code).toSet();
    return friendTt.courses
        .map((c) => c.code)
        .where(mineCodes.contains)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final semestersAsync = ref.watch(
      friendSharedSemestersProvider(widget.friend.id),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: mq.padding.top + 64 + 8),
                ),
                SliverToBoxAdapter(child: _FriendHeader(friend: widget.friend)),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ...semestersAsync.when(
                  loading: () => const <Widget>[
                    SliverToBoxAdapter(child: _LoadingBox()),
                  ],
                  error: (_, _) => const <Widget>[
                    SliverToBoxAdapter(
                      child: _MessageBox(
                        icon: Symbols.error,
                        title: '시간표를 불러오지 못했어요',
                        subtitle: '잠시 후 다시 시도해 주세요',
                      ),
                    ),
                  ],
                  data: (semesters) => _buildBody(mq, semesters),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 24 + mq.padding.bottom),
                ),
              ],
            ),
            _FriendTimetableAppBar(friend: widget.friend),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(MediaQueryData mq, List<Semester> semesters) {
    if (semesters.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: _MessageBox(
            icon: Symbols.event_busy,
            title: '아직 공유된 시간표가 없어요',
            subtitle: '친구가 앱에 로그인하면 학기별 시간표가 자동으로 올라와요',
          ),
        ),
      ];
    }

    // 기본 = 친구가 올린 가장 최근 학기(semesters는 최신순). 사용자가 고른 학기가
    // 더 이상 목록에 없으면(이론상 X) 최신으로 폴백.
    final semester = (_picked != null && semesters.contains(_picked))
        ? _picked!
        : semesters.first;

    final ttAsync = ref.watch(
      friendTimetableProvider((friendId: widget.friend.id, semester: semester)),
    );
    final friendTt =
        ttAsync.value ?? Timetable(semester: semester, courses: const []);
    final shared = _sharedCodes(friendTt, semester);

    return [
      SliverToBoxAdapter(
        child: SemesterStrip(
          selected: semester,
          available: semesters.toSet(),
          onSelected: (s) => setState(() => _picked = s),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(
        child: _SharedSummary(
          count: friendTt.courses.length,
          sharedCount: shared.length,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        sliver: SliverToBoxAdapter(
          child: ttAsync.isLoading && !ttAsync.hasValue
              ? const _LoadingBox()
              : TimetableGrid(
                  timetable: friendTt,
                  highlightCourseCodes: shared,
                ),
        ),
      ),
    ];
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        40,
        AppSpacing.marginMobile,
        40,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 38,
              color: AppColors.outline.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                fontSize: 12,
                height: 1.4,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTimetableAppBar extends StatelessWidget {
  const _FriendTimetableAppBar({required this.friend});
  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
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
            horizontal: AppSpacing.gutterMobile,
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Symbols.arrow_back,
                      size: 24,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${friend.name}의 시간표',
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.major,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendHeader extends StatelessWidget {
  const _FriendHeader({required this.friend});
  final Friend friend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _FriendHeaderAvatar(seed: friend.avatarSeed),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: AppTypography.headlineMd.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friend.major,
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedSummary extends StatelessWidget {
  const _SharedSummary({required this.count, required this.sharedCount});
  final int count;
  final int sharedCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Row(
        children: [
          _MiniBadge(
            icon: Symbols.menu_book,
            label: '$count과목',
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          if (sharedCount > 0)
            _MiniBadge(
              icon: Symbols.star,
              label: '같이 듣는 $sharedCount강의',
              color: AppColors.primary,
              filled: true,
            )
          else
            _MiniBadge(
              icon: Symbols.star_outline,
              label: '같이 듣는 강의 없음',
              color: AppColors.outline,
            ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.12)
            : AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: filled
              ? color.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, fill: filled ? 1 : 0, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontSize: 12,
              color: filled ? color : AppColors.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 친구 헤더 카드에 들어가는 큰 아바타 (52dp).
class _FriendHeaderAvatar extends StatelessWidget {
  const _FriendHeaderAvatar({required this.seed});
  final int seed;

  static const _gradients = AppSubjectPalette.gradients;

  @override
  Widget build(BuildContext context) {
    final g = _gradients[seed % _gradients.length];
    return SizedBox(
      width: 52,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: g,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: g[1].withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Symbols.person,
          size: 28,
          fill: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
