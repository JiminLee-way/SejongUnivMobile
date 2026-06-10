import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

/// 홈 hero 카드의 상단 컨텍스트 한 줄.
///
/// 시간표 상태를 7가지로 분기해 가장 정보량 있는 한 줄을 보여준다:
/// loading / error / noTimetable / weekendOrEmpty / beforeFirst / between / allDone.
///
/// flip 버튼이 우상단에 겹치지 않도록 [rightInset]만큼 오른쪽 여백 확보.
enum LectureContextState {
  loading,
  error,
  noTimetable,
  weekendOrEmpty,
  beforeFirst,
  between,
  allDone,
}

class LectureContextRow extends StatelessWidget {
  const LectureContextRow({
    super.key,
    required this.state,
    this.next,
    this.rightInset = 44,
  });

  /// 현재 시간표 상태. caller(home_screen)가 도출해서 넘긴다.
  final LectureContextState state;

  /// [LectureContextState.beforeFirst] / [LectureContextState.between]일 때만 사용.
  final ({Course course, HMTime startsAt})? next;

  /// 우상단 flip 버튼(36) + gap을 위해 비워둘 너비.
  final double rightInset;

  @override
  Widget build(BuildContext context) {
    final hasNext =
        state == LectureContextState.beforeFirst ||
        state == LectureContextState.between;
    final iconData = switch (state) {
      LectureContextState.loading => Symbols.hourglass_empty,
      LectureContextState.error => Symbols.cloud_off,
      LectureContextState.noTimetable => Symbols.event_busy,
      LectureContextState.weekendOrEmpty => Symbols.weekend,
      LectureContextState.allDone => Symbols.check_circle,
      LectureContextState.beforeFirst => Symbols.schedule,
      LectureContextState.between => Symbols.schedule,
    };
    final iconColor = switch (state) {
      LectureContextState.beforeFirst ||
      LectureContextState.between => AppColors.primary,
      LectureContextState.error => AppColors.primary,
      _ => AppColors.onSurfaceVariant,
    };

    return Padding(
      padding: EdgeInsets.only(right: rightInset),
      child: Row(
        children: [
          Icon(iconData, fill: 1, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: hasNext && next != null
                ? _NextText(course: next!.course, startsAt: next!.startsAt)
                : Text(
                    _fallbackText(state),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
          ),
        ],
      ),
    );
  }

  static String _fallbackText(LectureContextState s) => switch (s) {
    LectureContextState.loading => '시간표를 불러오는 중…',
    LectureContextState.error => '시간표를 불러오지 못했어요',
    LectureContextState.noTimetable => '이번 학기 시간표가 없어요',
    LectureContextState.weekendOrEmpty => '오늘은 수업이 없어요',
    LectureContextState.allDone => '오늘 강의 다 끝났어요',
    // hasNext이지만 next가 null인 방어 케이스.
    LectureContextState.beforeFirst ||
    LectureContextState.between => '다음 강의 정보가 없어요',
  };
}

class _NextText extends StatelessWidget {
  const _NextText({required this.course, required this.startsAt});
  final Course course;
  final HMTime startsAt;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
        children: [
          const TextSpan(text: '다음 강의 '),
          TextSpan(
            text: startsAt.format(),
            style: AppTypography.labelSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.0,
            ),
          ),
          const TextSpan(text: '  '),
          TextSpan(
            text: course.name,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
