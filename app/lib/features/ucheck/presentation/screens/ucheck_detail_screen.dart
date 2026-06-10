import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_status_colors.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_mobile_info.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/ucheck_providers.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/screens/ucheck_dispute_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 특정 강의의 출결 상세.
///
/// V1: 메인 화면에서 받은 `LectureWithAttendance`의 기본 정보만 표시 + 결석
/// cell 자리에 이의신청 진입 버튼. attendList.do (per-lecture 풀 이력) 호출은
/// V1.1에서 추가 — 현재는 mobile API daydata의 stateCd만으로 요약.
class UCheckDetailScreen extends ConsumerWidget {
  const UCheckDetailScreen({super.key, required this.lectureNo});

  final int lectureNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(ucheckDataProvider);
    final topPad = MediaQuery.paddingOf(context).top;
    // UCheckScreen이 root push되어 AppShell의 MeshBackground가 가려진다.
    // 이 화면은 그 위로 또 push되므로 부모 mesh도 안 보임 — 자체 mesh 필수.
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: topPad + 64),
                child: asyncData.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'UCheck 데이터를 불러오지 못했어요.\n$e',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  data: (data) {
                    if (data.lectures.isEmpty) {
                      return Center(
                        child: Text(
                          '강의 정보가 없어요',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final lecture = data.lectures.firstWhere(
                      (l) => l.lecture.lectureNo == lectureNo,
                      orElse: () => data.lectures.first,
                    );
                    return _DetailBody(lecture: lecture);
                  },
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(title: '출결 상세'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.lecture});
  final LectureWithAttendance lecture;

  @override
  Widget build(BuildContext context) {
    final l = lecture.lecture;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.curriculumNm.isEmpty ? '강의명 미상' : l.curriculumNm,
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: 4),
              Text(
                '${l.teacherNm ?? ""} · 강의번호 ${l.lectureNo}',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _StatsRow(lecture: lecture),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (lecture.beaconAddresses.isNotEmpty ||
            lecture.beaconLocalNames.isNotEmpty)
          _BeaconInfoCard(lecture: lecture),
        const SizedBox(height: 16),
        _WeeklyAttendanceCard(lecture: lecture),
      ],
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.lecture});
  final LectureWithAttendance lecture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // attendList.do로 실 출결 이력 fetch. 통계 + (V1.1) 주차표용.
    final async = ref.watch(
      ucheckLectureRecordsProvider(lecture.lecture.lectureNo),
    );
    return async.when(
      loading: () => const _StatsLoading(),
      error: (e, _) => _StatsErrorRow(message: '$e'),
      data: (records) {
        // 세종대 UCheck attend_type 매핑:
        //   1 = 출석
        //   2 = 지각
        //   3 = 결석
        //   4 = 결석 (조퇴 운영 X — 학교 정책상 4도 결석으로 처리)
        //   5 = 휴강
        final present = records.where((r) => r.attendType == '1').length;
        final late = records.where((r) => r.attendType == '2').length;
        final absent = records
            .where((r) => r.attendType == '3' || r.attendType == '4')
            .length;
        final holiday = records.where((r) => r.attendType == '5').length;
        final total = records.length;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: '전체',
                    value: total.toString(),
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: '출석',
                    value: present.toString(),
                    color: AppStatusColors.present,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: '지각',
                    value: late.toString(),
                    color: AppStatusColors.lateArrival,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: '결석',
                    value: absent.toString(),
                    color: AppStatusColors.absent,
                  ),
                ),
              ],
            ),
            if (holiday > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: '휴강',
                      value: holiday.toString(),
                      color: AppStatusColors.holiday,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 70,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _StatsErrorRow extends StatelessWidget {
  const _StatsErrorRow({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Symbols.error, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '출결 이력을 불러오지 못했어요',
              style: AppTypography.bodyMd.copyWith(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(value, style: AppTypography.headlineMd.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeaconInfoCard extends StatelessWidget {
  const _BeaconInfoCard({required this.lecture});
  final LectureWithAttendance lecture;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.bluetooth, size: 18, color: Colors.green),
              const SizedBox(width: 6),
              Text('등록된 비콘 정보', style: AppTypography.headlineMd),
            ],
          ),
          const SizedBox(height: 8),
          if (lecture.beaconAddresses.isNotEmpty)
            Text(
              'MAC: ${lecture.beaconAddresses.length}개',
              style: AppTypography.labelMd,
            ),
          if (lecture.beaconLocalNames.isNotEmpty)
            Text(
              'Local name: ${lecture.beaconLocalNames.join(", ")}',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'ap_type: ${lecture.apType}',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAttendanceCard extends ConsumerWidget {
  const _WeeklyAttendanceCard({required this.lecture});
  final LectureWithAttendance lecture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      ucheckLectureRecordsProvider(lecture.lecture.lectureNo),
    );
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.calendar_month, size: 18),
              const SizedBox(width: 6),
              Text('주차별 출결', style: AppTypography.headlineMd),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '출결 이력을 불러오지 못했어요',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            data: (records) {
              if (records.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '아직 출결 기록이 없어요',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                );
              }
              // 주차 → classNo 순 정렬 (서버는 최신순). 최신순 그대로 표시.
              return Column(
                children: [
                  for (final r in records)
                    _RecordRow(record: r, lecture: lecture),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.lecture});
  final UCheckMobileAttend record;
  final LectureWithAttendance lecture;

  @override
  Widget build(BuildContext context) {
    final at = _formatTime(record.attendTime);
    final date = _formatDate(
      record.attendDate.isEmpty
          ? (record.attendTime.length >= 8
                ? record.attendTime.substring(0, 8)
                : '')
          : record.attendDate,
    );
    final (label, color, icon) = _statusOf(record.attendType);
    // 결석 행은 칩 자체를 탭 가능하게 만들고 "이의신청" 보조 텍스트를 칩 안에
    // 작은 글씨로 표기. 별도 "신청" 액션 칩 없음 — 결석 칩 클릭으로 단일 진입.
    //  - objection_status == "2" → 이미 처리됨 (탭 비활성, "처리됨" 보조 텍스트)
    //  - 그 외 (미신청) → 탭 시 canSubmitObjection 분기:
    //      true  → showUCheckDisputeSheet
    //      false → "이의신청 기간이 지났습니다" 토스트
    final now = DateTime.now();
    final isAbsent = record.isAbsent;
    final isProcessed = isAbsent && record.objectionStatus == '2';
    final String? supplement;
    final VoidCallback? onChipTap;
    if (isAbsent && !isProcessed) {
      supplement = '이의신청';
      onChipTap = () {
        if (record.canSubmitObjection(now)) {
          showUCheckDisputeSheet(
            context,
            lectureNo: lecture.lecture.lectureNo,
            lectureWeek: int.tryParse(record.lectureWeek) ?? 0,
            classNo: int.tryParse(record.classNo) ?? 0,
            attendType: record.attendType,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이의신청 기간이 지났습니다.'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      };
    } else if (isProcessed) {
      supplement = '처리됨';
      onChipTap = null;
    } else {
      supplement = null;
      onChipTap = null;
    }

    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSm.copyWith(color: color)),
          if (supplement != null) ...[
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 9,
              color: color.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 6),
            Text(
              supplement,
              style: AppTypography.labelSm.copyWith(
                color: color.withValues(alpha: 0.85),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 주차
          SizedBox(
            width: 48,
            child: Text(
              '${record.lectureWeek}주 ${record.classNo}차',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 날짜
          SizedBox(width: 56, child: Text(date, style: AppTypography.labelMd)),
          // 시각
          Expanded(
            child: Text(
              at,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          // 상태 — 결석 + 미처리됨일 때만 탭 가능.
          if (onChipTap != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onChipTap,
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: statusChip,
              ),
            )
          else
            statusChip,
        ],
      ),
    );
  }

  /// yyyyMMddHHmmss → HH:mm:ss. attendDate(yyyyMMdd)면 빈 문자열.
  String _formatTime(String s) {
    if (s.length < 14) return '';
    return '${s.substring(8, 10)}:${s.substring(10, 12)}:${s.substring(12, 14)}';
  }

  /// yyyyMMdd → MM.dd
  String _formatDate(String s) {
    if (s.length < 8) return '';
    return '${s.substring(4, 6)}.${s.substring(6, 8)}';
  }

  (String, Color, IconData) _statusOf(String type) {
    // 세종대 UCheck 정책: 1=출석 / 2=지각 / 3,4=결석 (조퇴 운영 X) / 5=휴강
    switch (type) {
      case '1':
        return ('출석', AppStatusColors.present, Symbols.check_circle);
      case '2':
        return ('지각', AppStatusColors.lateArrival, Symbols.schedule);
      case '3':
      case '4':
        return ('결석', AppStatusColors.absent, Symbols.cancel);
      case '5':
        return ('휴강', AppStatusColors.holiday, Symbols.remove_circle);
      default:
        return ('-', AppColors.onSurfaceVariant, Symbols.help);
    }
  }
}
