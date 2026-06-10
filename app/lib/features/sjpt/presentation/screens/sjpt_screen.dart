import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/sjpt/data/repositories/sjpt_reservation_repository.dart';
import 'package:sejong_smart_campus/features/sjpt/domain/entities/sjpt_models.dart';
import 'package:sejong_smart_campus/features/sjpt/presentation/providers/sjpt_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

// ── 강의실 예약 유형코드
const _kClassroomTypeCd = 'GAI008001';

class SjptScreen extends ConsumerStatefulWidget {
  const SjptScreen({super.key});

  @override
  ConsumerState<SjptScreen> createState() => _SjptScreenState();
}

class _SjptScreenState extends ConsumerState<SjptScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(sjptInitProvider);
    ref.invalidate(sjptFacilitiesProvider);
    ref.invalidate(facilityImagesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _onRefreshReservations() async {
    ref.invalidate(sjptMyReservationsProvider);
    ref.invalidate(sjptLocalReservationsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final headerOffset = mq.padding.top + 56 + 44;

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(top: headerOffset),
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _FacilityTab(onRefresh: _onRefresh),
                    _MyReservationsTab(onRefresh: _onRefreshReservations),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(
                title: '학교 시설 대여',
                bottom: TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: '시설물 현황'),
                    Tab(text: '내 예약'),
                  ],
                ),
                bottomHeight: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Tab 1: 시설물 현황
// ═══════════════════════════════════════════════════════

class _FacilityTab extends ConsumerWidget {
  const _FacilityTab({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final facilitiesAsync = ref.watch(sjptFilteredFacilitiesProvider);
    final buildingsAsync = ref.watch(sjptBuildingsProvider);
    final selectedBuilding = ref.watch(sjptSelectedBuildingProvider);
    final selectedCategory = ref.watch(sjptSelectedCategoryProvider);
    final selectedDate = ref.watch(sjptSelectedDateProvider);

    return SejongRefresh(
      onRefresh: onRefresh,
      topInset: 0,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.marginMobile,
          12,
          AppSpacing.marginMobile,
          112 + mq.padding.bottom,
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _DateSelector(
            selected: selectedDate,
            onTap: () => _pickDate(context, ref, selectedDate),
          ),
          const SizedBox(height: 8),
          // 시설 유형 필터 (6개 고정 카테고리)
          _CategoryChips(
            selected: selectedCategory,
            onSelect: (c) {
              ref.read(sjptSelectedCategoryProvider.notifier).select(c);
              ref.read(sjptSelectedBuildingProvider.notifier).select(null);
            },
          ),
          const SizedBox(height: 8),
          // 건물 필터 (학생회관 카테고리는 서브필터 불필요)
          if (selectedCategory != SjptCategory.studentUnion)
            buildingsAsync.when(
              data: (buildings) => buildings.isEmpty
                  ? const SizedBox.shrink()
                  : _BuildingChips(
                      buildings: buildings,
                      selected: selectedBuilding,
                      onSelect: (b) => ref
                          .read(sjptSelectedBuildingProvider.notifier)
                          .select(b),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          const SizedBox(height: 12),
          // 시설물 날짜 제약 안내
          if (selectedCategory != SjptCategory.all &&
              selectedCategory != SjptCategory.classroom)
            const _DateConstraintBanner(isClassroom: false)
          else
            const _DateConstraintBanner(isClassroom: true),
          const SizedBox(height: 8),
          facilitiesAsync.when(
            data: (facilities) => facilities.isEmpty
                ? _EmptyState(onRefresh: onRefresh)
                : Column(
                    children: facilities
                        .map(
                          (f) => _FacilityCard(
                            facility: f,
                            date: _yyyymmdd(selectedDate),
                          ),
                        )
                        .toList(),
                  ),
            loading: () => const _LoadingState(),
            error: (e, _) =>
                _ErrorState(message: e.toString(), onRetry: onRefresh),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 42)),
    );
    if (picked != null) {
      ref.read(sjptSelectedDateProvider.notifier).select(picked);
    }
  }
}

// ═══════════════════════════════════════════════════════
// Tab 2: 내 예약
// ═══════════════════════════════════════════════════════

class _MyReservationsTab extends ConsumerWidget {
  const _MyReservationsTab({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final serverAsync = ref.watch(sjptMyReservationsProvider);
    final localAsync = ref.watch(sjptLocalReservationsProvider);

    // SJPT 서버 조회 성공이면 서버 데이터 우선. 실패 시 로컬 캐시로 폴백.
    return SejongRefresh(
      onRefresh: onRefresh,
      topInset: 0,
      child: serverAsync.when(
        data: (reservations) => reservations.isEmpty
            ? _buildEmpty(mq)
            : _buildServerList(mq, reservations, onRefresh),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => localAsync.when(
          data: (locals) =>
              locals.isEmpty ? _buildEmpty(mq) : _buildLocalList(mq, locals),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                err.toString(),
                style: AppTypography.bodyMd.copyWith(
                  color: const Color(0xFFB00020),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(MediaQueryData mq) => ListView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.marginMobile,
      32,
      AppSpacing.marginMobile,
      112 + mq.padding.bottom,
    ),
    children: const [_NoReservationsState()],
  );

  Widget _buildServerList(
    MediaQueryData mq,
    List<SjptReservation> reservations,
    Future<void> Function() onRefresh,
  ) => ListView.separated(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.marginMobile,
      12,
      AppSpacing.marginMobile,
      112 + mq.padding.bottom,
    ),
    physics: const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    itemCount: reservations.length,
    separatorBuilder: (context, i) => const SizedBox(height: 8),
    itemBuilder: (context, i) => _ReservationCard(reservation: reservations[i]),
  );

  Widget _buildLocalList(
    MediaQueryData mq,
    List<SjptLocalReservation> locals,
  ) => ListView.separated(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.marginMobile,
      12,
      AppSpacing.marginMobile,
      112 + mq.padding.bottom,
    ),
    physics: const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    itemCount: locals.length + 1,
    separatorBuilder: (context, i) => const SizedBox(height: 8),
    itemBuilder: (context, i) {
      if (i == 0) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCC02)),
          ),
          child: Row(
            children: [
              const Icon(Symbols.info, size: 16, color: Color(0xFF795548)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '세션 만료 — 저장된 예약 내역입니다. 최신 처리상태는 포털에서 확인하세요.',
                  style: AppTypography.labelSm.copyWith(
                    color: const Color(0xFF795548),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return _LocalReservationCard(local: locals[i - 1]);
    },
  );
}

// ── 서버 예약 카드 ──────────────────────────────────────────

class _ReservationCard extends ConsumerWidget {
  const _ReservationCard({required this.reservation});
  final SjptReservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reservation;
    final statusColor = r.isApproved
        ? const Color(0xFF4CAF50)
        : r.isCancelled
        ? AppColors.onSurfaceVariant
        : AppColors.primary;

    final statusLabel = r.treatStatusNm.isNotEmpty
        ? r.treatStatusNm
        : (r.isApproved ? '사용승인완료' : '처리중');

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.roomAbbt}  ${r.buildingName}',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: AppTypography.labelSm.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 신청번호
          Row(
            children: [
              Icon(
                Symbols.confirmation_number,
                size: 13,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '신청번호: ${r.useApplyNo}',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: r.useApplyNo));
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('신청번호가 복사되었습니다')),
                  );
                },
                child: Icon(
                  Symbols.copy_all,
                  size: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Symbols.calendar_today,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(r.useDateStart),
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Symbols.schedule,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${r.beginTime} ~ ${r.endTime}',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (r.purpose.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '사용목적: ${r.purpose}',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (r.regDate.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '신청일: ${r.regDate}',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showCancelInfo(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              child: const Text('취소 방법 안내'),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.info,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '예약 취소 안내',
                    style: AppTypography.headlineMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '시설물 예약 취소는 학사지원과(수업)에\n직접 연락하여야 합니다.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CancelPhoneRow(phone: '02-3408-3410'),
                    const SizedBox(height: 6),
                    _CancelPhoneRow(phone: '02-3408-3426'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    '확인',
                    style: AppTypography.labelMd.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 로컬 캐시 예약 카드 ─────────────────────────────────────

class _LocalReservationCard extends StatelessWidget {
  const _LocalReservationCard({required this.local});
  final SjptLocalReservation local;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${local.roomAbbt}  ${local.bldNm}',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (local.statusNm.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    local.statusNm,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Symbols.confirmation_number,
                size: 13,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '신청번호: ${local.useApplyNo}',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: local.useApplyNo));
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('신청번호가 복사되었습니다')),
                  );
                },
                child: Icon(
                  Symbols.copy_all,
                  size: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Symbols.calendar_today,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                local.formattedBgnDate,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Symbols.schedule,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                local.timeLabel,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (local.purpose.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '사용목적: ${local.purpose}',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoReservationsState extends StatelessWidget {
  const _NoReservationsState();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Symbols.event_busy, size: 48, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '예약 내역이 없습니다',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 날짜 선택 버튼
// ═══════════════════════════════════════════════════════

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.selected, required this.onTap});
  final DateTime selected;
  final VoidCallback onTap;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final label =
        '${selected.year}년 ${selected.month}월 ${selected.day}일 (${_weekdays[selected.weekday - 1]})';
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(Symbols.calendar_today, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(
              Symbols.chevron_right,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 날짜 제약 안내 배너
// ═══════════════════════════════════════════════════════

class _DateConstraintBanner extends StatelessWidget {
  const _DateConstraintBanner({required this.isClassroom});
  final bool isClassroom;

  @override
  Widget build(BuildContext context) {
    final msg = isClassroom
        ? '강의실: 신청일 기준 다음날부터 최대 3주까지 신청 가능'
        : '강의실 외 시설물: 신청일 기준 일주일 후부터 최대 7일간 신청 가능';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Symbols.info, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              msg,
              style: AppTypography.labelSm.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 시설 유형 필터 칩
// ═══════════════════════════════════════════════════════

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelect});
  final SjptCategory selected;
  final ValueChanged<SjptCategory> onSelect;

  static const _items = [
    (cat: SjptCategory.all, label: '전체'),
    (cat: SjptCategory.classroom, label: '강의실'),
    (cat: SjptCategory.lab, label: '실험실'),
    (cat: SjptCategory.sports, label: '체육·공연'),
    (cat: SjptCategory.studentUnion, label: '학생회관'),
    (cat: SjptCategory.other, label: '그외'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _items
            .map(
              (item) => _Chip(
                label: item.label,
                selected: selected == item.cat,
                onTap: () => onSelect(item.cat),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 건물 필터 칩
// ═══════════════════════════════════════════════════════

class _BuildingChips extends StatelessWidget {
  const _BuildingChips({
    required this.buildings,
    required this.selected,
    required this.onSelect,
  });
  final List<String> buildings;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: '전체',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...buildings.map(
            (b) => _Chip(
              label: b,
              selected: selected == b,
              onTap: () => onSelect(b == selected ? null : b),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: selected ? Colors.white : AppColors.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 시설 이미지 헬퍼 — Supabase facility_images (서버 구동)
// ═══════════════════════════════════════════════════════

/// 시설 이미지 URL — Supabase `facility_images` 우선 조회(room_abbt 정확 매칭),
/// 없으면 레거시 대양AI센터 규칙 폴백.
///
/// 서버 구동이라 관리자가 `facility_images` 행만 추가하면(이미지 업로드 + URL)
/// APK 재빌드 없이 새 시설 사진이 노출된다. [ref]로 provider를 watch하므로
/// 반드시 build() 중에 호출한다.
String? _facilityImageUrl(WidgetRef ref, SjptFacility f) {
  final byAbbt = ref.watch(facilityImagesProvider).value;
  final url = byAbbt?[f.roomAbbt];
  if (url != null && url.isNotEmpty) return url;
  return _legacyAicenterImageUrl(f);
}

/// 레거시 폴백 — facility_images 미적재/네트워크 실패 시에도 대양AI센터
/// 이미지(B###)는 유지해 회복력을 보장한다. DB에 해당 room_abbt 행이 있으면
/// 그쪽이 우선(위 함수에서 먼저 반환).
String? _legacyAicenterImageUrl(SjptFacility f) {
  if (!f.buildingName.contains('AI')) return null;
  final base = SupabaseConfig.publicStorageBase('facility-images/aicenter');
  if (base == null) return null;
  final pattern = RegExp(r'[Bb]\d{3}');
  for (final s in [f.roomAbbt, f.roomName, f.roomNo]) {
    final m = pattern.firstMatch(s);
    if (m != null) return '$base/${m.group(0)!.toUpperCase()}.jpeg';
  }
  return null;
}

// ═══════════════════════════════════════════════════════
// 시설물 카드
// ═══════════════════════════════════════════════════════

class _FacilityCard extends ConsumerWidget {
  const _FacilityCard({required this.facility, required this.date});
  final SjptFacility facility;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = _facilityImageUrl(ref, facility);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showTimeTable(context),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 이미지 또는 아이콘 배너
                if (imageUrl != null)
                  _RoomImage(url: imageUrl)
                else
                  _RoomIconBanner(typeCd: facility.typeCd),
                // 하단: 이름 + 건물
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              facility.roomAbbt,
                              style: AppTypography.bodyMd.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${facility.buildingName} · ${facility.roomName}',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Symbols.chevron_right,
                        size: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTimeTable(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimeTableSheet(facility: facility, date: date),
    );
  }
}

// ── 강의실 이미지 위젯 ──────────────────────────────────────

class _RoomImage extends StatelessWidget {
  const _RoomImage({required this.url, this.height = 140});
  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (ctx, _) => Container(
          height: height,
          color: AppColors.surfaceContainerLow,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (ctx, u, err) => _RoomIconBanner(typeCd: ''),
      ),
    );
  }
}

class _RoomIconBanner extends StatelessWidget {
  const _RoomIconBanner({required this.typeCd});
  final String typeCd;

  @override
  Widget build(BuildContext context) {
    final icon = switch (typeCd) {
      'GAI008001' => Symbols.school,
      'GAI008002' => Symbols.science,
      'GAI008013' => Symbols.sports_soccer,
      'GAI008014' => Symbols.theater_comedy,
      _ => Symbols.meeting_room,
    };
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Icon(
        icon,
        size: 32,
        color: AppColors.primary.withValues(alpha: 0.4),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 시간표 바텀시트
// ═══════════════════════════════════════════════════════

class _TimeTableSheet extends ConsumerStatefulWidget {
  const _TimeTableSheet({required this.facility, required this.date});
  final SjptFacility facility;
  final String date;

  @override
  ConsumerState<_TimeTableSheet> createState() => _TimeTableSheetState();
}

class _TimeTableSheetState extends ConsumerState<_TimeTableSheet> {
  late String _sheetDate;
  int? _startIdx;
  int? _endIdx;

  @override
  void initState() {
    super.initState();
    _sheetDate = widget.date;
  }

  void _showOccupiedDetail(BuildContext context, SjptTimeSlot slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OccupiedSlotSheet(slot: slot, date: _sheetDate),
    );
  }

  void _toggleSlot(int idx, List<SjptTimeSlot> slots) {
    final slot = slots[idx];
    if (!slot.isAvailable) return;
    setState(() {
      if (_startIdx == null) {
        _startIdx = _endIdx = idx;
        return;
      }
      // 같은 슬롯 재탭 → 선택 해제
      if (_startIdx == idx && _endIdx == idx) {
        _startIdx = _endIdx = null;
        return;
      }
      // 범위 확장 — startIdx 이후이고 사이에 사용중인 슬롯 없어야 함
      if (idx >= _startIdx!) {
        final allAvail = List.generate(
          idx - _startIdx! + 1,
          (i) => _startIdx! + i,
        ).every((i) => i < slots.length && slots[i].isAvailable);
        if (allAvail) {
          _endIdx = idx;
          return;
        }
      }
      // 그 외: 새 선택으로 초기화
      _startIdx = _endIdx = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final args = (roomAbbt: widget.facility.roomAbbt, date: _sheetDate);
    final slotsAsync = ref.watch(sjptTimeTableProvider(args));
    final instanceAsync = ref.watch(sjptFacilityInstanceProvider(args));
    final displayDate =
        '${_sheetDate.substring(0, 4)}년 ${int.parse(_sheetDate.substring(4, 6))}월 '
        '${int.parse(_sheetDate.substring(6, 8))}일';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDt = DateTime(
      int.parse(_sheetDate.substring(0, 4)),
      int.parse(_sheetDate.substring(4, 6)),
      int.parse(_sheetDate.substring(6, 8)),
    );
    final isClassroom = widget.facility.typeCd == _kClassroomTypeCd;
    final minDate = isClassroom
        ? today.add(const Duration(days: 1))
        : today.add(const Duration(days: 7));
    final dateOk = !selectedDt.isBefore(minDate);

    final slots = slotsAsync.value;
    final effectiveInstance =
        instanceAsync.value ??
        (slots != null ? _buildFallbackInstance(slots) : null);
    final hasSelection = _startIdx != null && _endIdx != null && slots != null;
    final canSubmit = hasSelection && dateOk && effectiveInstance != null;

    final imageUrl = _facilityImageUrl(ref, widget.facility);

    return DraggableScrollableSheet(
      initialChildSize: imageUrl != null ? 0.88 : 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.facility.roomAbbt,
                          style: AppTypography.headlineMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.facility.buildingName} · ${widget.facility.roomName}',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayDate,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Symbols.close,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 날짜 제약 배너
            if (!dateOk)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Symbols.warning,
                        size: 14,
                        color: Color(0xFFE65100),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isClassroom
                              ? '강의실은 내일(${_formatDate(_yyyymmdd(minDate))})부터 신청 가능합니다'
                              : '이 시설물은 ${_formatDate(_yyyymmdd(minDate))}부터 신청 가능합니다',
                          style: AppTypography.labelSm.copyWith(
                            color: const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 강의실 이미지 (AI센터)
            if (imageUrl != null) _RoomImage(url: imageUrl, height: 160),
            Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.2)),
            // 가로 눈금자 타임라인
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  (canSubmit ? 80 : 20) + mq.padding.bottom,
                ),
                child: slotsAsync.when(
                  data: (loadedSlots) => loadedSlots.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              '시간표 정보 없음',
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RulerTimeline(
                              slots: loadedSlots,
                              startIdx: _startIdx,
                              endIdx: _endIdx,
                              dateOk: dateOk,
                              onSlotTap: (i) => _toggleSlot(i, loadedSlots),
                              onOccupiedTap: (i) =>
                                  _showOccupiedDetail(context, loadedSlots[i]),
                            ),
                            const SizedBox(height: 20),
                            _RulerLegend(
                              dateOk: dateOk,
                              isLoading: instanceAsync.isLoading,
                            ),
                            const SizedBox(height: 16),
                            _SheetDateNavigator(
                              date: _sheetDate,
                              isClassroom: isClassroom,
                              onDateChanged: (newDate) => setState(() {
                                _sheetDate = newDate;
                                _startIdx = null;
                                _endIdx = null;
                              }),
                            ),
                          ],
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      e.toString(),
                      style: AppTypography.labelSm.copyWith(
                        color: const Color(0xFFB00020),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 예약 신청 바
            if (hasSelection)
              _SelectionBar(
                startSlot: slots[_startIdx!],
                endSlot: slots[_endIdx!],
                canSubmit: canSubmit,
                onSubmit: canSubmit
                    ? () => _openReservationForm(
                        context,
                        slots,
                        effectiveInstance,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  /// doListInst.do 가 null 반환 시 타임테이블 슬롯의 FACILITY_MNGT_NO로 대체 인스턴스 생성.
  SjptFacilityInstance? _buildFallbackInstance(List<SjptTimeSlot> slots) {
    final f = widget.facility;
    final slot = slots.firstWhere(
      (s) => s.facilityMngtNo.isNotEmpty,
      orElse: () => const SjptTimeSlot(
        roomAbbt: '',
        useDate: '',
        timeFrom: '',
        timeTo: '',
        period: '',
        applicantName: '',
        deptName: '',
        purpose: '',
        phone: '',
        remark: '',
        facilityMngtNo: '',
        buildingNo: '',
        buildingName: '',
        roomNo: '',
        roomName: '',
        typeCd: '',
        maxCapacity: 0,
        minPeople: 1,
      ),
    );
    if (slot.facilityMngtNo.isEmpty) return null;
    return SjptFacilityInstance(
      facilityMngtNo: slot.facilityMngtNo,
      roomAbbt: f.roomAbbt,
      roomName: f.roomName,
      buildingName: f.buildingName,
      buildingNo: f.buildingNo,
      roomNo: f.roomNo,
      typeCd: f.typeCd,
      maxCapacity: slot.maxCapacity,
      minPeople: slot.minPeople,
      useTimeFrom: '',
      useTimeTo: '',
      notes: '',
      cableMicCount: 0,
      wirelessMicCount: 0,
      hasElecTable: false,
      hasElecApproval: false,
      directYn: 'N',
      operDeptName: '',
      remark: '',
    );
  }

  void _openReservationForm(
    BuildContext context,
    List<SjptTimeSlot> slots,
    SjptFacilityInstance instance,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReservationFormSheet(
        slot: slots[_startIdx!],
        endTime: slots[_endIdx!].timeTo,
        instance: instance,
        date: _sheetDate,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 가로 눈금자 타임라인
// ═══════════════════════════════════════════════════════

class _RulerTimeline extends StatelessWidget {
  const _RulerTimeline({
    required this.slots,
    required this.startIdx,
    required this.endIdx,
    required this.dateOk,
    required this.onSlotTap,
    this.onOccupiedTap,
  });

  final List<SjptTimeSlot> slots;
  final int? startIdx;
  final int? endIdx;
  final bool dateOk;
  final void Function(int idx) onSlotTap;
  final void Function(int idx)? onOccupiedTap;

  static const double _slotW = 56.0;
  static const double _trackH = 46.0;
  static const double _labelH = 20.0;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();
    final totalWidth = slots.length * _slotW;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시간 선택',
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            height: _labelH + _trackH,
            child: Stack(
              children: [
                // 시간 레이블 (매 정시)
                Positioned(
                  top: 0,
                  left: 0,
                  width: totalWidth,
                  height: _labelH,
                  child: Stack(
                    children: [
                      for (int i = 0; i < slots.length; i++)
                        if (i == 0 || slots[i].timeFrom.endsWith(':00'))
                          Positioned(
                            left: i == 0 ? 0 : i * _slotW - 14,
                            top: 2,
                            child: Text(
                              slots[i].timeFrom,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                      Positioned(
                        left: totalWidth - 30,
                        top: 2,
                        child: Text(
                          slots.last.timeTo,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 슬롯 트랙
                Positioned(
                  top: _labelH,
                  left: 0,
                  width: totalWidth,
                  height: _trackH,
                  child: Row(
                    children: [
                      for (int i = 0; i < slots.length; i++) _buildSlotBlock(i),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotBlock(int idx) {
    final slot = slots[idx];
    final isAvail = slot.isAvailable;
    final isSelected =
        startIdx != null &&
        endIdx != null &&
        idx >= startIdx! &&
        idx <= endIdx!;
    final isHalfHour = slot.timeFrom.endsWith(':30');

    Color bgColor = Colors.transparent;
    Color topBorderColor = AppColors.outline.withValues(alpha: 0.25);
    Color bottomBorderColor = AppColors.outline.withValues(alpha: 0.25);

    if (isAvail && isSelected) {
      bgColor = AppColors.primary.withValues(alpha: 0.12);
      topBorderColor = AppColors.primary;
      bottomBorderColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: isAvail && dateOk
          ? () => onSlotTap(idx)
          : (!isAvail ? () => onOccupiedTap?.call(idx) : null),
      child: Container(
        width: _slotW,
        height: _trackH,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(color: topBorderColor, width: isSelected ? 1.5 : 1),
            bottom: BorderSide(
              color: bottomBorderColor,
              width: isSelected ? 1.5 : 1,
            ),
            right: BorderSide(
              color: isHalfHour
                  ? AppColors.outline.withValues(alpha: 0.12)
                  : AppColors.outline.withValues(alpha: 0.3),
            ),
            left: idx == 0
                ? BorderSide(color: AppColors.outline.withValues(alpha: 0.25))
                : BorderSide.none,
          ),
        ),
        child: Stack(
          children: [
            if (!isAvail)
              ClipRect(
                child: CustomPaint(
                  painter: _HatchPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            if (isAvail && isSelected)
              const Center(
                child: Icon(Symbols.check, size: 16, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 빗금 패턴 CustomPainter ──────────────────────────────────

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const spacing = 7.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => false;
}

// ── 타임라인 범례 ─────────────────────────────────────────────

class _RulerLegend extends StatelessWidget {
  const _RulerLegend({required this.dateOk, required this.isLoading});
  final bool dateOk;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: Colors.transparent,
          borderColor: AppColors.outline.withValues(alpha: 0.3),
          label: '예약가능',
        ),
        _LegendItem(isHatch: true, label: '사용중'),
        _LegendItem(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderColor: AppColors.primary,
          icon: Symbols.check,
          label: '선택됨',
        ),
        if (!dateOk)
          _LegendItem(
            color: const Color(0xFFFFF3E0),
            borderColor: const Color(0xFFFFB74D),
            label: '신청불가',
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    this.color,
    this.borderColor,
    this.icon,
    this.isHatch = false,
    required this.label,
  });
  final Color? color;
  final Color? borderColor;
  final IconData? icon;
  final bool isHatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: borderColor ?? AppColors.outline.withValues(alpha: 0.2),
            ),
          ),
          child: isHatch
              ? ClipRect(child: CustomPaint(painter: _HatchPainter()))
              : (icon != null
                    ? Icon(icon, size: 10, color: AppColors.primary)
                    : null),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// 바텀시트 날짜 이동 위젯
// ═══════════════════════════════════════════════════════

class _SheetDateNavigator extends StatelessWidget {
  const _SheetDateNavigator({
    required this.date,
    required this.isClassroom,
    required this.onDateChanged,
  });

  final String date; // "20260527"
  final bool isClassroom;
  final ValueChanged<String> onDateChanged;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final dt = DateTime(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(4, 6)),
      int.parse(date.substring(6, 8)),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = isClassroom
        ? today.add(const Duration(days: 1))
        : today.add(const Duration(days: 7));
    final maxDate = isClassroom
        ? today.add(const Duration(days: 21))
        : today.add(const Duration(days: 14));

    final canPrev = dt.isAfter(minDate);
    final canNext = dt.isBefore(maxDate);

    final dayLabel = '${dt.month}월 ${dt.day}일 (${_weekdays[dt.weekday - 1]})';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: canPrev
                ? () => onDateChanged(
                    _yyyymmdd(dt.subtract(const Duration(days: 1))),
                  )
                : null,
            iconSize: 22,
            icon: Icon(
              Symbols.chevron_left,
              color: canPrev
                  ? AppColors.onSurface
                  : AppColors.outline.withValues(alpha: 0.4),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '날짜 변경',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.calendar_today,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    dayLabel,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: canNext
                ? () =>
                      onDateChanged(_yyyymmdd(dt.add(const Duration(days: 1))))
                : null,
            iconSize: 22,
            icon: Icon(
              Symbols.chevron_right,
              color: canNext
                  ? AppColors.onSurface
                  : AppColors.outline.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 점유 슬롯 상세 바텀시트 (신청자/소속/전화/신청번호)
// ═══════════════════════════════════════════════════════

class _OccupiedSlotSheet extends ConsumerWidget {
  const _OccupiedSlotSheet({required this.slot, required this.date});
  final SjptTimeSlot slot;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (
      placeDivCd: slot.placeDivCd,
      bldNo: slot.buildingNo,
      roomNo: slot.roomNo,
      bldNm: slot.buildingName,
      roomAbbt: slot.roomAbbt,
      useDate: date,
    );
    final reservationsAsync = ref.watch(sjptSlotReservationsProvider(args));

    // 이 슬롯에 해당하는 신청번호 찾기
    final applyNo = reservationsAsync.whenOrNull(
      data: (list) {
        try {
          return list
              .firstWhere((r) => r.containsSlot(slot.timeFrom))
              .useApplyNo;
        } catch (_) {
          return null;
        }
      },
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      painter: _HatchPainter(),
                      child: const SizedBox(width: 16, height: 10),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '사용중',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${slot.timeFrom} ~ ${slot.timeTo}  ${slot.period}',
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          // 신청번호
          _DetailRow(
            icon: Symbols.confirmation_number,
            label: '신청번호',
            value: reservationsAsync.isLoading
                ? null
                : (applyNo?.isNotEmpty == true ? applyNo! : '—'),
            isLoading: reservationsAsync.isLoading,
            valueStyle: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          // 신청자
          _DetailRow(
            icon: Symbols.person,
            label: '신청자',
            value: slot.applicantName,
          ),
          const SizedBox(height: 10),
          // 소속
          _DetailRow(
            icon: Symbols.corporate_fare,
            label: '소속',
            value: slot.deptName.isNotEmpty ? slot.deptName : '—',
          ),
          const SizedBox(height: 10),
          // 전화번호
          _DetailRow(
            icon: Symbols.phone,
            label: '전화번호',
            value: slot.phone.isNotEmpty ? slot.phone : '—',
          ),
          if (slot.purpose.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailRow(icon: Symbols.notes, label: '사용목적', value: slot.purpose),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLoading = false,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool isLoading;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: isLoading
              ? SizedBox(
                  height: 14,
                  width: 80,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.outline.withValues(alpha: 0.2),
                    color: AppColors.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  value ?? '—',
                  style:
                      valueStyle ??
                      AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
        ),
      ],
    );
  }
}

class _CancelPhoneRow extends StatelessWidget {
  const _CancelPhoneRow({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Symbols.phone, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          phone,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// 시간 범위 선택 바 (다중 슬롯)
// ═══════════════════════════════════════════════════════

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.startSlot,
    required this.endSlot,
    required this.canSubmit,
    this.onSubmit,
  });
  final SjptTimeSlot startSlot;
  final SjptTimeSlot endSlot;
  final bool canSubmit;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + mq.padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: AppColors.outline.withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${startSlot.period} ~ ${endSlot.period}',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${startSlot.timeFrom} ~ ${endSlot.timeTo}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('예약 신청'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 예약 신청 폼 바텀시트
// ═══════════════════════════════════════════════════════

class _ReservationFormSheet extends ConsumerStatefulWidget {
  const _ReservationFormSheet({
    required this.slot,
    required this.instance,
    required this.date,
    this.endTime,
  });
  final SjptTimeSlot slot;
  final SjptFacilityInstance instance;
  final String date;

  /// 다중 슬롯 선택 시 마지막 슬롯의 종료 시간 (null = 단일 슬롯).
  final String? endTime;

  @override
  ConsumerState<_ReservationFormSheet> createState() =>
      _ReservationFormSheetState();
}

class _ReservationFormSheetState extends ConsumerState<_ReservationFormSheet> {
  final _purposeCtrl = TextEditingController();
  final _advisorCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _etcCtrl = TextEditingController();

  int _people = 1;
  bool _loading = false;
  bool _notesConfirmed = false;
  bool _outsider = false;
  bool _hvac = false;
  bool _lighting = false;
  bool _projector = false;
  bool _elecTable = false;
  bool _otsdEqm = false;
  int _cableMic = 0;
  int _wirelessMic = 0;

  @override
  void initState() {
    super.initState();
    _people = widget.instance.minPeople.clamp(1, 999);
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _advisorCtrl.dispose();
    _orgCtrl.dispose();
    _etcCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final inst = widget.instance;
    final slot = widget.slot;
    final isClassroom = inst.typeCd == _kClassroomTypeCd;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '사용신청',
                          style: AppTypography.headlineMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${slot.roomAbbt}  ${slot.timeFrom} ~ ${widget.endTime ?? slot.timeTo}',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (inst.operDeptName.isNotEmpty)
                          Text(
                            '운영부서: ${inst.operDeptName}',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          '최소 ${inst.minPeople}명 / 최대 ${inst.maxCapacity}명',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Symbols.close,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 16,
              color: AppColors.outline.withValues(alpha: 0.2),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  24 + mq.viewInsets.bottom + mq.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 필수 항목 ────────────────────────────
                    _SectionHeader('필수 항목'),
                    const SizedBox(height: 12),
                    _RequiredLabel('사용 목적'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _purposeCtrl,
                      decoration: _inputDeco('구체적인 사용 목적 입력 (예: 학술회의)'),
                      maxLength: 100,
                      maxLines: 2,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                    ),
                    const SizedBox(height: 16),
                    _RequiredLabel('사용 인원'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _CounterButton(
                          icon: Symbols.remove,
                          onPressed: _people > inst.minPeople.clamp(1, 999)
                              ? () => setState(() => _people--)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$_people명',
                            style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _CounterButton(
                          icon: Symbols.add,
                          onPressed:
                              inst.maxCapacity == 0 ||
                                  _people < inst.maxCapacity
                              ? () => setState(() => _people++)
                              : null,
                        ),
                      ],
                    ),
                    // ── 선택 항목 ────────────────────────────
                    const SizedBox(height: 20),
                    _SectionHeader('선택 항목'),
                    const SizedBox(height: 12),
                    _FormLabel('소속 단체명'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _orgCtrl,
                      decoration: _inputDeco('소속 단체명 입력 (예: 연구실, 동아리)'),
                    ),
                    const SizedBox(height: 16),
                    _FormLabel('외부인 참가 여부'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _ToggleChip(
                          label: '미참가',
                          selected: !_outsider,
                          onTap: () => setState(() => _outsider = false),
                        ),
                        const SizedBox(width: 8),
                        _ToggleChip(
                          label: '참가',
                          selected: _outsider,
                          onTap: () => setState(() => _outsider = true),
                        ),
                      ],
                    ),
                    if (isClassroom) ...[
                      const SizedBox(height: 16),
                      _FormLabel('지도교수명'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _advisorCtrl,
                        decoration: _inputDeco('지도교수명 입력'),
                      ),
                    ],
                    // ── 요청 물품 ────────────────────────────
                    const SizedBox(height: 20),
                    _SectionHeader('요청 물품'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CheckboxChip(
                          label: '냉난방',
                          value: _hvac,
                          onChanged: (v) => setState(() => _hvac = v),
                        ),
                        _CheckboxChip(
                          label: '조명',
                          value: _lighting,
                          onChanged: (v) => setState(() => _lighting = v),
                        ),
                        _CheckboxChip(
                          label: '빔프로젝터',
                          value: _projector,
                          onChanged: (v) => setState(() => _projector = v),
                        ),
                        if (inst.hasElecTable)
                          _CheckboxChip(
                            label: '전자교탁',
                            value: _elecTable,
                            onChanged: (v) => setState(() => _elecTable = v),
                          ),
                        _CheckboxChip(
                          label: '외부장비',
                          value: _otsdEqm,
                          onChanged: (v) => setState(() => _otsdEqm = v),
                        ),
                      ],
                    ),
                    if (inst.cableMicCount > 0) ...[
                      const SizedBox(height: 16),
                      _FormLabel('유선마이크 수 (최대 ${inst.cableMicCount}개)'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CounterButton(
                            icon: Symbols.remove,
                            onPressed: _cableMic > 0
                                ? () => setState(() => _cableMic--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_cableMic개',
                              style: AppTypography.bodyMd,
                            ),
                          ),
                          _CounterButton(
                            icon: Symbols.add,
                            onPressed: _cableMic < inst.cableMicCount
                                ? () => setState(() => _cableMic++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                    if (inst.wirelessMicCount > 0) ...[
                      const SizedBox(height: 16),
                      _FormLabel('무선마이크 수 (최대 ${inst.wirelessMicCount}개)'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CounterButton(
                            icon: Symbols.remove,
                            onPressed: _wirelessMic > 0
                                ? () => setState(() => _wirelessMic--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_wirelessMic개',
                              style: AppTypography.bodyMd,
                            ),
                          ),
                          _CounterButton(
                            icon: Symbols.add,
                            onPressed: _wirelessMic < inst.wirelessMicCount
                                ? () => setState(() => _wirelessMic++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _FormLabel('기타 요청사항'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _etcCtrl,
                      decoration: _inputDeco('기타 요청사항'),
                      maxLines: 2,
                    ),
                    // ── 유의사항 ─────────────────────────────
                    if (inst.notes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHeader('사용신청 주의사항'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          inst.notes,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _notesConfirmed = !_notesConfirmed),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _notesConfirmed,
                              onChanged: (v) =>
                                  setState(() => _notesConfirmed = v ?? false),
                              activeColor: AppColors.primary,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Text(
                              '위 주의사항을 확인했습니다 *',
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // ── 제출 버튼 ─────────────────────────────
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '사용신청',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surfaceContainerLow,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Future<void> _submit() async {
    final purpose = _purposeCtrl.text.trim();
    if (purpose.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용 목적을 입력해주세요')));
      return;
    }
    if (widget.instance.notes.isNotEmpty && !_notesConfirmed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주의사항을 먼저 확인해주세요')));
      return;
    }

    setState(() => _loading = true);
    try {
      final client = await ref.read(sjptClientProvider.future);
      final slot = widget.slot;
      final inst = widget.instance;
      final from = slot.timeFrom.replaceAll(':', '');
      final to = (widget.endTime ?? slot.timeTo).replaceAll(':', '');
      final bgnH = from.substring(0, 2);
      final bgnM = from.substring(2, 4);
      final endH = to.substring(0, 2);
      final endM = to.substring(2, 4);

      // 시간 중복 확인
      final ok = await client.checkTimeConflict(
        bldNo: inst.buildingNo,
        roomNo: inst.roomNo,
        startDate: widget.date,
        endDate: widget.date,
        bgnHour: bgnH,
        bgnMin: bgnM,
        endHour: endH,
        endMin: endM,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 예약된 시간입니다. 다른 시간을 선택해주세요')),
        );
        return;
      }

      // 신청 제출
      final applyNo = await client.saveReservation(
        facilityMngtNo: inst.facilityMngtNo,
        bldNo: inst.buildingNo,
        bldNm: inst.buildingName,
        roomNo: inst.roomNo,
        roomNm: inst.roomName,
        roomAbbt: inst.roomAbbt,
        instTpCd: inst.typeCd,
        useDate: widget.date,
        endDate: widget.date,
        bgnHour: bgnH,
        bgnMin: bgnM,
        endHour: endH,
        endMin: endM,
        usePeople: _people,
        purpose: purpose,
        notes: inst.notes,
        notesConfirmed: _notesConfirmed,
        orgName: _orgCtrl.text.trim(),
        advisorName: _advisorCtrl.text.trim(),
        outlndAtndncFlag: _outsider ? 'Y' : 'N',
        cdysmFlag: _hvac ? 'Y' : 'N',
        lghtFlag: _lighting ? 'Y' : 'N',
        bmprjtYn: _projector ? 'Y' : 'N',
        elecTblUseFlag: _elecTable ? 'Y' : 'N',
        otsdEqmUseFlag: _otsdEqm ? 'Y' : 'N',
        cbleMicQty: _cableMic,
        wrlessMicQty: _wirelessMic,
        etc: _etcCtrl.text.trim(),
        maxCapacity: inst.maxCapacity,
        minPeople: inst.minPeople,
        elecAprvYn: inst.hasElecApproval ? 'Y' : 'N',
      );

      // Supabase 캐시에 최소 정보 저장
      final repo = ref.read(sjptReservationRepositoryProvider);
      await repo.saveReservation(
        useApplyNo: applyNo,
        bldNm: inst.buildingName,
        bldNo: inst.buildingNo,
        roomAbbt: inst.roomAbbt,
        roomNm: inst.roomName,
        roomNo: inst.roomNo,
        useBgnDt: widget.date,
        useEndDt: widget.date,
        bgnTime: '$bgnH:$bgnM',
        endTime: '$endH:$endM',
        purpose: purpose,
        usePeople: _people,
        orgName: _orgCtrl.text.trim(),
        advisorNm: _advisorCtrl.text.trim(),
      );

      if (!mounted) return;

      // 폼 + 시간표 시트 닫기
      Navigator.pop(context);
      Navigator.pop(context);

      // 성공 다이얼로그
      await _showSuccessDialog(context, applyNo, inst);

      ref.invalidate(sjptMyReservationsProvider);
      ref.invalidate(sjptLocalReservationsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('신청 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSuccessDialog(
    BuildContext context,
    String applyNo,
    SjptFacilityInstance inst,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        applyNo: applyNo,
        roomAbbt: inst.roomAbbt,
        buildingName: inst.buildingName,
        date: widget.date,
        bgnTime: widget.slot.timeFrom,
        endTime: widget.endTime ?? widget.slot.timeTo,
        isClassroom: inst.typeCd == _kClassroomTypeCd,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 예약 완료 다이얼로그
// ═══════════════════════════════════════════════════════

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({
    required this.applyNo,
    required this.roomAbbt,
    required this.buildingName,
    required this.date,
    required this.bgnTime,
    required this.endTime,
    required this.isClassroom,
  });

  final String applyNo;
  final String roomAbbt;
  final String buildingName;
  final String date;
  final String bgnTime;
  final String endTime;
  final bool isClassroom;

  @override
  Widget build(BuildContext context) {
    final displayDate = date.length == 8
        ? '${date.substring(0, 4)}년 ${int.parse(date.substring(4, 6))}월 ${int.parse(date.substring(6, 8))}일'
        : date;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.check_circle,
                size: 32,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '신청 완료',
              style: AppTypography.headlineMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$buildingName $roomAbbt',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '$displayDate · $bgnTime ~ $endTime',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 신청번호
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '신청번호',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        applyNo,
                        style: AppTypography.headlineMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: applyNo));
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(content: Text('신청번호가 복사되었습니다')),
                          );
                        },
                        child: Icon(
                          Symbols.copy_all,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 수업과 방문 안내 (강의실인 경우)
            if (isClassroom)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC02)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.info,
                          size: 14,
                          color: Color(0xFF795548),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '필수 방문 안내',
                          style: AppTypography.labelSm.copyWith(
                            color: const Color(0xFF795548),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '학생회관 2층 수업과를 방문하여\n사용허가서를 작성하여야 합니다.',
                      style: AppTypography.labelSm.copyWith(
                        color: const Color(0xFF795548),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '※ 마이크 등 음향시설은 교강사실(광107호)에\n   허가서 제출 후 대여 가능',
                      style: AppTypography.labelSm.copyWith(
                        color: const Color(0xFFBCAAA4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 폼 공통 위젯 ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: AppTypography.labelMd.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Divider(
          color: AppColors.outline.withValues(alpha: 0.25),
          height: 1,
        ),
      ),
    ],
  );
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(width: 3),
      Text(
        '*',
        style: AppTypography.labelMd.copyWith(color: const Color(0xFFB00020)),
      ),
    ],
  );
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
  );
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outline,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(
          color: selected ? Colors.white : AppColors.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _CheckboxChip extends StatelessWidget {
  const _CheckboxChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? AppColors.primary : AppColors.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value ? Symbols.check_box : Symbols.check_box_outline_blank,
            size: 16,
            color: value ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: value ? AppColors.primary : AppColors.onSurface,
              fontWeight: value ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: onPressed != null
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onPressed != null
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Icon(
        icon,
        size: 18,
        color: onPressed != null
            ? AppColors.primary
            : AppColors.onSurfaceVariant,
      ),
    ),
  );
}

// ─── 공통 에러/로딩/빈 상태 ──────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(Symbols.search_off, size: 48, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          '시설물이 없습니다',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRefresh, child: const Text('다시 불러오기')),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Icon(Symbols.error_outline, size: 40, color: const Color(0xFFB00020)),
        const SizedBox(height: 8),
        Text(
          message,
          style: AppTypography.labelSm.copyWith(color: const Color(0xFFB00020)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

// ─── 헬퍼 ─────────────────────────────────────────────────

String _yyyymmdd(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _formatDate(String yyyymmdd) {
  if (yyyymmdd.length != 8) return yyyymmdd;
  return '${yyyymmdd.substring(0, 4)}.${yyyymmdd.substring(4, 6)}.${yyyymmdd.substring(6)}';
}
