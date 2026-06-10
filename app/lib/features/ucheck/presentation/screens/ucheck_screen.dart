import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_status_colors.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/core/demo/demo.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_api_client.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/attendance_outcome.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_data.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_settings_provider.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/ucheck_providers.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/screens/ucheck_detail_screen.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/screens/ucheck_login_screen.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/screens/ucheck_settings_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// UCheck 메인 — 오늘 강의 + 출석 체크 버튼 + 출결 요약.
///
/// 실 데이터 흐름:
/// 1. `ucheckDataProvider` watch — `UCheckRepository.initialize()`
/// 2. AsyncValue.when:
///    - data → 강의 카드 리스트
///    - error == [UCheckUnauthenticatedException] → fallback 로그인 모달
///    - error else → "다시 시도" 카드
///    - loading → skeleton
class UCheckScreen extends ConsumerStatefulWidget {
  const UCheckScreen({super.key});

  @override
  ConsumerState<UCheckScreen> createState() => _UCheckScreenState();
}

class _UCheckScreenState extends ConsumerState<UCheckScreen> {
  bool _loginPromptShown = false;
  bool _showAll = false;

  Future<void> _onRefresh() async {
    ref.invalidate(ucheckDataProvider);
    await ref.read(ucheckDataProvider.future);
  }

  Future<void> _promptLogin() async {
    if (_loginPromptShown) return;
    _loginPromptShown = true;
    final ok = await showUCheckLoginSheet(context);
    if (ok != true && mounted) {
      _loginPromptShown = false;
    }
  }

  void _showOutcomeSnackBar(AttendanceOutcome outcome) {
    String msg;
    Color bg;
    switch (outcome) {
      case AttendedOutcome(:final isLate):
        msg = isLate ? '지각 처리되었어요' : '출석 완료!';
        bg = isLate ? Colors.orange : Colors.green;
      case AlreadyAttendedOutcome():
        msg = '이미 출석 처리되어 있어요';
        bg = Colors.blueGrey;
      case OutOfWindowOutcome(:final reasonKor):
        msg = reasonKor;
        bg = Colors.orange;
      case FailedOutcome(:final reason):
        msg = reason;
        bg = Colors.red;
      case CooldownOutcome():
        msg = '잠시 후 다시 시도해주세요';
        bg = Colors.blueGrey;
      case NoEligibleLectureOutcome():
        msg = '출석 가능한 강의가 없어요';
        bg = Colors.blueGrey;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 출석 체크 결과 → SnackBar 노출 + dismiss.
    ref.listen<AttendCheckState>(attendCheckCommandProvider, (prev, next) {
      switch (next) {
        case AttendCheckResult(:final outcome):
          _showOutcomeSnackBar(outcome);
          // 다음 트리거를 위해 idle로 리셋.
          Future.microtask(
            () => ref.read(attendCheckCommandProvider.notifier).dismiss(),
          );
        case AttendCheckErrorState(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          Future.microtask(
            () => ref.read(attendCheckCommandProvider.notifier).dismiss(),
          );
        case AttendCheckScanning():
        case AttendCheckIdle():
          break;
      }
    });

    final asyncData = ref.watch(ucheckDataProvider);
    final botPad = MediaQuery.paddingOf(context).bottom;
    final topInset = SejongSubAppBar.heightFor(context);

    // sub-screen 패턴 — 열람실/학식/시설예약과 동일하게 뒤로가기 버튼이 있는
    // SejongSubAppBar + MeshBackground (push되면 AppShell의 mesh를 덮으므로
    // 자체 mesh가 필요). bottom nav가 root navigator 아래에 가려지므로 하단
    // padding은 safe area만.
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              bottom: false,
              child: SejongRefresh(
                onRefresh: _onRefresh,
                topInset: topInset,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: topInset + 16,
                    left: AppSpacing.marginMobile,
                    right: AppSpacing.marginMobile,
                    bottom: 24 + botPad,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _StudentInfoCard(asyncData: asyncData),
                    const SizedBox(height: AppSpacing.stackMd),
                    asyncData.when(
                      loading: () => const _LoadingPlaceholder(),
                      error: (e, _) => _ErrorCard(
                        error: e,
                        onRetry: _onRefresh,
                        onLoginNeeded: _promptLogin,
                      ),
                      data: (data) => _LecturesList(
                        data: data,
                        showAll: _showAll,
                        onToggleShowAll: () =>
                            setState(() => _showAll = !_showAll),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(
                title: 'U-Check',
                actions: [_SettingsButton()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends ConsumerWidget {
  const _SettingsButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEnabled = ref.watch(autoAttendEnabledProvider);
    final enabled = asyncEnabled.value ?? false;
    return Stack(
      children: [
        IconButton(
          onPressed: () => showUCheckSettingsSheet(context),
          icon: const Icon(Symbols.tune),
          tooltip: '자동출석 설정',
        ),
        if (enabled)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Subwidgets ────────────────────────────────────────────────────────

class _StudentInfoCard extends ConsumerWidget {
  const _StudentInfoCard({required this.asyncData});
  final AsyncValue<UCheckData> asyncData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(displayUserProvider);
    final data = asyncData.value;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Symbols.school, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.username ?? '학생', style: AppTypography.headlineMd),
                const SizedBox(height: 2),
                Text(
                  user?.userId ?? '',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (data != null && data.totalWeeks > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${data.currentWeek}주차',
                style: AppTypography.labelSm.copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 80,
              child: Center(
                child: i == 0
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  const _ErrorCard({
    required this.error,
    required this.onRetry,
    required this.onLoginNeeded,
  });
  final Object error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLoginNeeded;

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  @override
  void initState() {
    super.initState();
    if (widget.error is UCheckUnauthenticatedException) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onLoginNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = widget.error is UCheckUnauthenticatedException;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            isAuth ? Symbols.lock : Symbols.cloud_off,
            size: 40,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            isAuth ? 'UCheck 자격증명이 필요해요' : 'UCheck 데이터를 불러오지 못했어요',
            style: AppTypography.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isAuth ? '비밀번호를 입력해주세요' : widget.error.toString(),
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => isAuth ? widget.onLoginNeeded() : widget.onRetry(),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(isAuth ? '로그인' : '다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _LecturesList extends StatelessWidget {
  const _LecturesList({
    required this.data,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final UCheckData data;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  /// 오늘의 UCheck day_week — 공유 [ucheckDayWeek] 사용(SSOT).
  static String _todayDayWeek() => ucheckDayWeek(DateTime.now());

  /// **lecture_no 기준 중복 제거 + 오늘 entry 우선 선택**.
  ///
  /// mobile API 응답에는 화/목 같은 강의가 day_week별로 따로 들어옴
  /// (같은 lecture_no 두 entry). 우리는 강의 카드를 한 번만 보여줘야 하니 dedup.
  ///
  /// **출석체크 정확성 보장**: 오늘 day_week와 일치하는 entry가 있으면 그걸
  /// 우선 선택 — daydata가 오늘의 정확한 class_no/curWeek/attend_smin/비콘을
  /// 들고 있음. attendCheck.do payload는 이 entry 기준으로 구성되므로 정확.
  List<LectureWithAttendance> _dedupByLectureNo() {
    final todayKey = _todayDayWeek();
    final byNo = <int, LectureWithAttendance>{};
    for (final l in data.lectures) {
      final existing = byNo[l.lecture.lectureNo];
      if (existing == null) {
        byNo[l.lecture.lectureNo] = l;
      } else if (l.dayWeek == todayKey && existing.dayWeek != todayKey) {
        // 오늘 entry로 교체 (정확한 class_no/curWeek/비콘 우선)
        byNo[l.lecture.lectureNo] = l;
      }
    }
    return byNo.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final todayKey = _todayDayWeek();
    final deduped = _dedupByLectureNo();
    final visible = showAll
        ? deduped
        : deduped.where((l) => l.dayWeek == todayKey).toList();

    if (visible.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Symbols.calendar_today, size: 40),
            const SizedBox(height: 12),
            Text(
              showAll ? '강의 정보가 없어요' : '오늘 강의가 없어요',
              style: AppTypography.headlineMd,
            ),
            const SizedBox(height: 8),
            if (!showAll)
              TextButton(
                onPressed: onToggleShowAll,
                child: const Text('전체 강의 보기'),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              showAll ? '전체 강의 ${visible.length}개' : '오늘 강의 ${visible.length}개',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: onToggleShowAll,
              child: Text(showAll ? '오늘만 보기' : '전체 보기'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final lecture in visible) ...[
          _LectureCard(lecture: lecture),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LectureCard extends ConsumerWidget {
  const _LectureCard({required this.lecture});
  final LectureWithAttendance lecture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendState = ref.watch(attendCheckCommandProvider);
    final isScanning = attendState is AttendCheckScanning;
    final l = lecture.lecture;

    // 출석 윈도우 — 1초 틱으로 09:50 열림/10:15 마감을 실시간 반영.
    // (자동출석 funnel과 동일한 SSOT [AttendWindowX] 사용.)
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now();
    final windowState = lecture.attendWindowAt(now);
    final alreadyAttended = lecture.stateCdAttend != 0;
    final isLate = windowState == AttendWindowState.lateOpen;
    // 비활성(회색)은 **출석 마감(closed)·다른 요일(notToday)·이미 출석·스캔 중**일 때만.
    // "출석 시간 전(beforeOpen)"은 사용자 요청대로 이전처럼 활성 유지 — 일찍 눌러도
    // 서버가 최종 검증(시간 외 안내). unknown(파싱 실패)도 활성(서버가 판단).
    final windowBlocks =
        windowState == AttendWindowState.closed ||
        windowState == AttendWindowState.notToday;
    final canAttend = !windowBlocks && !alreadyAttended && !isScanning;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.curriculumNm.isNotEmpty ? l.curriculumNm : '강의명 미상',
                  style: AppTypography.headlineMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (lecture.beaconAddresses.isNotEmpty ||
                  lecture.beaconLocalNames.isNotEmpty)
                _BeaconChip(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.teacherNm ?? '',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    slideRoute(UCheckDetailScreen(lectureNo: l.lectureNo)),
                  ),
                  icon: const Icon(Symbols.list_alt, size: 18),
                  label: const Text('출결 상세'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canAttend ? () => _onAttend(context, ref) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: isLate
                        ? AppStatusColors.lateArrival
                        : AppColors.primary,
                    // 윈도우 밖/이미 출석/스캔 중 → on-brand 회색 비활성.
                    disabledBackgroundColor: AppColors.surfaceContainerHighest,
                    disabledForegroundColor: AppColors.onSurfaceVariant,
                  ),
                  icon: Icon(
                    alreadyAttended
                        ? Symbols.check_circle
                        : canAttend
                        ? Symbols.check_circle
                        : Symbols.schedule,
                    size: 18,
                    fill: alreadyAttended ? 1 : 0,
                  ),
                  label: Text(
                    _attendLabel(
                      isScanning: isScanning,
                      alreadyAttended: alreadyAttended,
                      windowState: windowState,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 버튼 라벨 — 윈도우 단계/스캔/이미출석에 따라.
  String _attendLabel({
    required bool isScanning,
    required bool alreadyAttended,
    required AttendWindowState windowState,
  }) {
    if (isScanning) return '스캔 중…';
    if (alreadyAttended) return '출석 완료';
    switch (windowState) {
      // 출석 시간 전도 이전처럼 그냥 "출석 체크"(활성).
      case AttendWindowState.onTime:
      case AttendWindowState.beforeOpen:
      case AttendWindowState.unknown:
        return '출석 체크';
      case AttendWindowState.lateOpen:
        return '지각 출석';
      case AttendWindowState.closed:
        return '출석 마감';
      case AttendWindowState.notToday:
        return '오늘 강의 아님';
    }
  }

  Future<void> _onAttend(BuildContext context, WidgetRef ref) async {
    if (lecture.beaconAddresses.isEmpty && lecture.beaconLocalNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 강의는 비콘 정보가 없어요. 다른 출석 방법을 사용해주세요.')),
      );
      return;
    }

    // 시작만 트리거 — 결과는 parent screen의 ref.listen이 처리.
    await ref.read(attendCheckCommandProvider.notifier).start(lecture);
  }
}

class _BeaconChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.bluetooth, size: 12, color: Colors.green.shade700),
          const SizedBox(width: 3),
          Text(
            'BLE',
            style: AppTypography.labelSm.copyWith(color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }
}
