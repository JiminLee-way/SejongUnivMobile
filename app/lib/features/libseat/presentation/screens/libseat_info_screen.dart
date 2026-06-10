import 'package:flutter/material.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/facility_models.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 시설 예약 안내 — 스터디룸 / 시네마룸 / S-Lounge.
///
/// AppBar의 (i) 아이콘에서 push. 3개 섹션을 한 ScrollView에 묶고 카테고리
/// chips로 빠른 점프(앵커) 가능.
class LibseatInfoScreen extends StatefulWidget {
  const LibseatInfoScreen({
    super.key,
    this.initial = FacilityCategory.studyRoom,
  });
  final FacilityCategory initial;

  @override
  State<LibseatInfoScreen> createState() => _LibseatInfoScreenState();
}

class _LibseatInfoScreenState extends State<LibseatInfoScreen> {
  final _scrollCtrl = ScrollController();
  final _keys = <FacilityCategory, GlobalKey>{
    for (final c in FacilityCategory.values) c: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollTo(widget.initial),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollTo(FacilityCategory cat) {
    final key = _keys[cat];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: ListView(
                controller: _scrollCtrl,
                padding: EdgeInsets.only(
                  top: mq.padding.top + 64 + 12,
                  left: AppSpacing.marginMobile,
                  right: AppSpacing.marginMobile,
                  bottom: 32 + mq.padding.bottom,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  _AnchorChips(onTap: _scrollTo),
                  const SizedBox(height: 16),
                  _SectionCard(
                    key: _keys[FacilityCategory.studyRoom],
                    title: '스터디룸',
                    intro:
                        '스터디룸은 학술정보원 4층에 총 13개실이 마련되어 있으며, 학생들의 효율적인 팀 프로젝트와 자기주도적 그룹 학습을 지원하기 위해 조성된 다목적 복합공간입니다. 학습 기자재가 구비되어 있어 단순한 모임을 넘어 분임토의, 발표수업 준비 등 다양한 토론 학습에 활용할 수 있습니다. 공간은 12인실 1개실과 6인실 12개실로 구성되어 있으며, 심도 있는 학술 토의와 프레젠테이션 준비에도 적합합니다.',
                    location: '학술정보원 4층',
                    rooms: const [
                      '01스터디룸(12)',
                      '02스터디룸(6)',
                      '03스터디룸(6)',
                      '04스터디룸(6)',
                      '05스터디룸(6)',
                      '06스터디룸(6)',
                      '07스터디룸(6)',
                      '08스터디룸(6)',
                      '09스터디룸(6)',
                      '10스터디룸(6)',
                      '11스터디룸(6)',
                      '12스터디룸(6)',
                      '13스터디룸(6)',
                    ],
                    hoursSemester: const [
                      '평일(월~금) 10:00 ~ 21:00',
                      '토요일 10:00 ~ 16:00',
                      '일요일, 공휴일 이용 불가',
                    ],
                    hoursVacation: const [
                      '평일(월~금) 10:00 ~ 16:00',
                      '휴일(토·일), 공휴일 이용 불가',
                    ],
                    useTime: '1시간 단위 예약, 최대 2시간까지 이용 가능 (예약은 일주일 전부터 가능)',
                    warnings: const [
                      '본인 포함 3~12인 이용 가능(각 실별로 최소인원이 다름)',
                      '예약자, 동반예약자 모두 예약시간 기준 20분 전후 학술정보원 게이트를 통과해야 승인처리',
                      '동반이용자로 등록되지 않은 이용자는 입실 불가',
                      '스터디룸 내 음식물 반입 및 취식 금지',
                      '실내 비품 사용에 주의 바라며, 파손 시 배상 처리',
                      '실내 소음으로 인한 주변의 피해가 없도록 주의',
                      '강의용으로 사용 불가',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    key: _keys[FacilityCategory.cinema],
                    title: '시네마룸',
                    intro:
                        '시네마룸은 학술정보원 1층에 위치한 다목적 복합문화공간으로, 콘텐츠 감상 및 소규모 모임에 적합한 시설입니다. TV를 통해 유튜브와 웨이브(Wavve) 스트리밍 서비스를 학교 계정으로 간편하게 이용할 수 있으며, 컴퓨터가 연결되어 있어 회의나 발표 등 다양한 용도로 활용할 수 있습니다. 시네마룸은 총 6개의 실로 구성되어 있으며, 각 실은 1~3명이 이용 가능합니다.',
                    location: '학술정보원 1층',
                    rooms: const [
                      '시네마룸1(3)',
                      '시네마룸2(3)',
                      '시네마룸3(3)',
                      '시네마룸4(3)',
                      '시네마룸5(3)',
                      '시네마룸6(3)',
                    ],
                    hoursSemester: const [
                      '평일(월~금) 10:00 ~ 21:00',
                      '토요일 10:00 ~ 16:00',
                      '일요일, 공휴일 이용 불가',
                    ],
                    hoursVacation: const [
                      '평일(월~금) 10:00 ~ 16:00',
                      '휴일(토·일), 공휴일 이용 불가',
                    ],
                    useTime: '1시간 단위 예약, 최대 2시간까지 이용 가능 (예약은 일주일 전부터 가능)',
                    warnings: const [
                      '사용 전 멀티미디어실을 방문하여 예약자와 동반이용자 확인 후 리모콘 수령',
                      '예약자, 동반예약자 모두 예약시간 기준 20분 전후 학술정보원 게이트를 통과해야 승인처리',
                      '동반이용자로 등록되지 않은 이용자는 입실 불가',
                      '시네마룸 내 음식물 반입 및 취식 금지',
                      '실내 비품 사용에 주의 바라며, 파손 시 배상처리',
                      '실내 소음으로 인한 주변의 피해가 없도록 주의',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    key: _keys[FacilityCategory.sLounge],
                    title: 'S-Lounge',
                    intro:
                        'S라운지는 학술정보원 2층에 위치한 그룹 학습과 휴식을 위한 다목적 복합문화공간으로, 6인실 9개실과 4인실 9개실, 예약 없이 자유롭게 이용할 수 있는 SL7을 포함해 총 19개실로 구성되어 있습니다. 자유로운 토론과 학습, 휴식과 소통이 이루어지는 지식 창조 공간으로 그룹 스터디와 토론 학습에 적합하며, 마루 공간과 빈백이 마련되어 있어 창의적인 학습과 편안한 휴식이 가능합니다. S라운지는 학기중에만 예약제로 운영됩니다.',
                    location: '학술정보원 2층',
                    rooms: const [
                      'SL1(6)',
                      'SL2(6)',
                      'SL3(4)',
                      'SL4(4)',
                      'SL5(4)',
                      'SL6(4)',
                      'SL8(4)',
                      'SL8(6)',
                      'SL9(6)',
                      'SL10(6)',
                      'SL11(6)',
                      'SL12(6)',
                      'SL13(6)',
                      'SL14(6)',
                      'SL15(4)',
                      'SL16(4)',
                      'SL17(4)',
                      'SL18(4)',
                      'SL19(4)',
                    ],
                    hoursSemester: const [
                      '평일(월~금) 10:00 ~ 21:00',
                      '토요일 10:00 ~ 16:00',
                      '일요일, 공휴일 이용 불가',
                    ],
                    hoursVacation: const ['자율 이용'],
                    useTime: '1시간 단위 예약, 최대 2시간까지 이용 가능 (예약은 일주일 전부터 가능)',
                    warnings: const [
                      '본인 포함 2~6인 이용 가능(각 실별로 최소인원이 다름)',
                      '예약자, 동반예약자 모두 예약시간 기준 20분 전후 학술정보원 게이트를 통과해야 승인처리',
                      '동반이용자로 등록되지 않은 이용자는 입실 불가',
                      '음식물 반입 및 취식 금지',
                      '비품 사용에 주의 바라며, 파손 시 배상처리',
                      '소음으로 인한 주변의 피해가 없도록 주의',
                    ],
                  ),
                ],
              ),
            ),
            const Align(alignment: Alignment.topCenter, child: _InfoAppBar()),
          ],
        ),
      ),
    );
  }
}

class _InfoAppBar extends StatelessWidget {
  const _InfoAppBar();
  @override
  Widget build(BuildContext context) {
    return const SejongSubAppBar(title: '시설 예약 안내');
  }
}

class _AnchorChips extends StatelessWidget {
  const _AnchorChips({required this.onTap});
  final ValueChanged<FacilityCategory> onTap;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final c in FacilityCategory.values)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => onTap(c),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  c.label,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.intro,
    required this.location,
    required this.rooms,
    required this.hoursSemester,
    required this.hoursVacation,
    required this.useTime,
    required this.warnings,
  });

  final String title;
  final String intro;
  final String location;
  final List<String> rooms;
  final List<String> hoursSemester;
  final List<String> hoursVacation;
  final String useTime;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            intro,
            style: AppTypography.bodyMd.copyWith(
              fontSize: 13,
              color: AppColors.onSurface,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          _LabeledRow(label: '위치', text: location),
          const SizedBox(height: 12),
          _LabeledHeader(label: '실별 수용인원'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in rooms)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    r,
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _LabeledHeader(label: '운영시간 — 학기중'),
          const SizedBox(height: 4),
          for (final line in hoursSemester) _Bullet(text: line),
          const SizedBox(height: 10),
          _LabeledHeader(label: '운영시간 — 방학중'),
          const SizedBox(height: 4),
          for (final line in hoursVacation) _Bullet(text: line),
          const SizedBox(height: 14),
          _LabeledHeader(label: '이용 시간'),
          const SizedBox(height: 4),
          Text(
            useTime,
            style: AppTypography.bodyMd.copyWith(
              fontSize: 13,
              color: AppColors.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _LabeledHeader(label: '주의사항'),
          const SizedBox(height: 4),
          for (final w in warnings) _Bullet(text: w),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.text});
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: AppTypography.labelMd.copyWith(
              fontSize: 12.5,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMd.copyWith(
              fontSize: 13,
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledHeader extends StatelessWidget {
  const _LabeledHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.labelMd.copyWith(
        fontSize: 12.5,
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 7, right: 8),
            decoration: const BoxDecoration(
              color: AppColors.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMd.copyWith(
                fontSize: 12.5,
                color: AppColors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
