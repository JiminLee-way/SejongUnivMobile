import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/facility_models.dart';
import 'package:sejong_smart_campus/features/shell/presentation/widgets/bottom_nav_insets.dart';

/// 예약 결정 한 명.
class Companion {
  const Companion({
    required this.name,
    this.studentId,
    this.department,
    this.isSelf = false,
  });

  final String name;

  /// 학번 — 직접 입력 시 필수. 친구 목록에서 추가 시엔 서버가 복호화해
  /// 채운다(확정 친구 학번 공개 정책). 데이터 없으면 null → '학번 미상'.
  final String? studentId;
  final String? department;
  final bool isSelf;

  String get displayStudentId => studentId ?? '학번 미상';
}

/// 예약 확인 모달 — 선택된 룸과 시간대를 보여주고, 동반이용자를 모은 뒤
/// 최소 인원이 충족되면 예약 실행 콜백을 호출.
///
/// 백엔드 reserveSlot은 동반이용자 정보를 받는 endpoint가 정찰되지 않아 현
/// 단계에선 UI 흐름만 완성. 호출 시 학번 list를 함께 넘기는 hook은 v2에서.
Future<List<Companion>?> showReservationConfirmSheet(
  BuildContext context, {
  required RoomSchedule room,
  required int startHour,
  required int durationHours,
  required Future<bool> Function(List<Companion>) onConfirm,
}) {
  return showModalBottomSheet<List<Companion>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReservationConfirmSheet(
      room: room,
      startHour: startHour,
      durationHours: durationHours,
      onConfirm: onConfirm,
    ),
  );
}

class _ReservationConfirmSheet extends ConsumerStatefulWidget {
  const _ReservationConfirmSheet({
    required this.room,
    required this.startHour,
    required this.durationHours,
    required this.onConfirm,
  });

  final RoomSchedule room;
  final int startHour;
  final int durationHours;
  final Future<bool> Function(List<Companion>) onConfirm;

  @override
  ConsumerState<_ReservationConfirmSheet> createState() =>
      _ReservationConfirmSheetState();
}

class _ReservationConfirmSheetState
    extends ConsumerState<_ReservationConfirmSheet> {
  final List<Companion> _companions = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 현재 사용자(본인)는 첫 항목으로 기본 포함.
    final me = ref.read(currentUserProvider);
    if (me != null) {
      _companions.add(
        Companion(
          name: me.username,
          studentId: me.userId,
          department: me.departmentName,
          isSelf: true,
        ),
      );
    }
  }

  Future<void> _openAddCompanion() async {
    final added = await showCompanionAddSheet(
      context,
      existingIds: _companions
          .map((c) => c.studentId)
          .whereType<String>()
          .toSet(),
      existingNames: _companions.map((c) => c.name).toSet(),
    );
    if (added == null || added.isEmpty || !mounted) return;
    setState(() => _companions.addAll(added));
  }

  void _removeAt(int i) {
    setState(() => _companions.removeAt(i));
  }

  Future<void> _onSubmit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onConfirm(List.unmodifiable(_companions));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop(_companions);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final endHour = widget.startHour + widget.durationHours;
    final missing = widget.room.minCapacity - _companions.length;
    final canSubmit = missing <= 0 && !_busy;
    // AppShell의 bottom nav가 sheet 위에 z-order로 떠 있어 하단 콘텐츠를
    // 가린다. 측정된 nav 높이를 padding으로 더해 예약하기 버튼이 nav 위로
    // 올라오도록 함.
    final navHeight = BottomNavInsets.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: AppColors.surface,
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            24 + navHeight + (navHeight > 0 ? 0 : mq.padding.bottom),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '예약 확인',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _RoomTimeCard(
                room: widget.room,
                startHour: widget.startHour,
                endHour: endHour,
                durationHours: widget.durationHours,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Symbols.groups,
                    size: 18,
                    fill: 1,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '동반이용자',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_companions.length}명',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '최소 ${widget.room.minCapacity}명',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _companions.length; i++) ...[
                _CompanionTile(
                  companion: _companions[i],
                  onRemove: _companions[i].isSelf ? null : () => _removeAt(i),
                ),
                if (i != _companions.length - 1) const SizedBox(height: 6),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _openAddCompanion,
                  icon: const Icon(Symbols.person_add, size: 18, fill: 1),
                  label: const Text('동반이용자 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit ? _onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.outline.withValues(
                      alpha: 0.3,
                    ),
                    disabledForegroundColor: AppColors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          missing > 0 ? '최소 $missing명을 추가해주세요' : '예약하기',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
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

class _RoomTimeCard extends StatelessWidget {
  const _RoomTimeCard({
    required this.room,
    required this.startHour,
    required this.endHour,
    required this.durationHours,
  });
  final RoomSchedule room;
  final int startHour;
  final int endHour;
  final int durationHours;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.schedule,
            size: 20,
            color: AppColors.primary,
            fill: 0,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${room.roomLabel} (${room.maxCapacity}인실)',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${startHour.toString().padLeft(2, '0')}:00 ~ '
                  '${endHour.toString().padLeft(2, '0')}:00',
                  style: AppTypography.labelMd.copyWith(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$durationHours시간',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionTile extends StatelessWidget {
  const _CompanionTile({required this.companion, this.onRemove});
  final Companion companion;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final initial = companion.name.isNotEmpty ? companion.name[0] : '?';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: companion.isSelf
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: companion.isSelf
              ? AppColors.primary.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: companion.isSelf
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: AppTypography.labelMd.copyWith(
                color: companion.isSelf ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        companion.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (companion.isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '본인',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  companion.department == null
                      ? companion.displayStudentId
                      : '${companion.displayStudentId} · ${companion.department}',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Symbols.close,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
              splashRadius: 18,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

// ─── 동반이용자 추가 sheet ────────────────────────────────────────────────────

/// 친구 목록 또는 직접 입력 탭. 선택된 사람 list를 반환.
Future<List<Companion>?> showCompanionAddSheet(
  BuildContext context, {
  required Set<String> existingIds,
  required Set<String> existingNames,
}) {
  return showModalBottomSheet<List<Companion>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CompanionAddSheet(
      existingIds: existingIds,
      existingNames: existingNames,
    ),
  );
}

class _CompanionAddSheet extends ConsumerStatefulWidget {
  const _CompanionAddSheet({
    required this.existingIds,
    required this.existingNames,
  });
  final Set<String> existingIds;
  final Set<String> existingNames;

  @override
  ConsumerState<_CompanionAddSheet> createState() => _CompanionAddSheetState();
}

class _CompanionAddSheetState extends ConsumerState<_CompanionAddSheet> {
  int _tab = 0;
  // 친구 목록 탭 — friendId 기반 선택 집합.
  final Set<String> _selectedFriendIds = {};
  // 직접 입력 탭 form.
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _formError;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submitFromFriends() {
    // 학번 자동입력을 위해 SupabaseFriend(학번 포함)에서 직접 매핑.
    // _selectedFriendIds는 friendId(=tt.Friend.id) 기준이라 그대로 매칭된다.
    final friends = ref.read(myFriendsProvider).value ?? const [];
    final picked = friends
        .where((f) => _selectedFriendIds.contains(f.friendId))
        .map(
          (f) => Companion(
            name: f.name,
            // 확정 친구 한정 학번 공개(사용자 정책) — 서버가 복호화해
            // 내려준 학번으로 동반이용자 자동입력. 없으면(구버전 등) null 폴백.
            studentId: (f.studentId ?? '').isEmpty ? null : f.studentId,
            department: (f.department ?? '').isEmpty ? null : f.department,
          ),
        )
        .toList();
    Navigator.of(context).pop(picked);
  }

  void _submitFromManual() {
    final id = _idCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (id.isEmpty || name.isEmpty) {
      setState(() => _formError = '학번과 이름을 모두 입력해주세요');
      return;
    }
    if (!RegExp(r'^\d{8}$').hasMatch(id)) {
      setState(() => _formError = '학번은 8자리 숫자여야 해요');
      return;
    }
    if (widget.existingIds.contains(id)) {
      setState(() => _formError = '이미 추가된 학번이에요');
      return;
    }
    Navigator.of(context).pop([Companion(name: name, studentId: id)]);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navHeight = BottomNavInsets.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: AppColors.surface,
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            24 + navHeight + (navHeight > 0 ? 0 : mq.padding.bottom),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '동반이용자 추가',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '친구 목록에서 선택하거나 직접 입력할 수 있습니다',
                style: AppTypography.labelMd.copyWith(
                  fontSize: 12.5,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _Segmented(
                tab: _tab,
                onChanged: (i) => setState(() {
                  _tab = i;
                  _formError = null;
                }),
              ),
              const SizedBox(height: 14),
              if (_tab == 0)
                _FriendsTab(
                  existingIds: widget.existingIds,
                  existingNames: widget.existingNames,
                  selected: _selectedFriendIds,
                  onToggle: (id) => setState(() {
                    if (_selectedFriendIds.contains(id)) {
                      _selectedFriendIds.remove(id);
                    } else {
                      _selectedFriendIds.add(id);
                    }
                  }),
                )
              else
                _ManualTab(
                  idCtrl: _idCtrl,
                  nameCtrl: _nameCtrl,
                  error: _formError,
                  onChanged: () {
                    if (_formError != null) {
                      setState(() => _formError = null);
                    }
                  },
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _tab == 0
                      ? (_selectedFriendIds.isEmpty ? null : _submitFromFriends)
                      : _submitFromManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.outline.withValues(
                      alpha: 0.3,
                    ),
                    disabledForegroundColor: AppColors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '완료',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
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

class _Segmented extends StatelessWidget {
  const _Segmented({required this.tab, required this.onChanged});
  final int tab;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _segment(
            label: '친구 목록',
            selected: tab == 0,
            onTap: () => onChanged(0),
          ),
          _segment(
            label: '직접 입력',
            selected: tab == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({
    required this.existingIds,
    required this.existingNames,
    required this.selected,
    required this.onToggle,
  });
  final Set<String> existingIds;
  final Set<String> existingNames;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(myFriendsAsLegacyProvider);
    final pool = friends.where((f) => !existingNames.contains(f.name)).toList();
    if (pool.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '등록된 친구가 없어요',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: pool.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final f = pool[i];
          final isSelected = selected.contains(f.id);
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onToggle(f.id),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        f.name.isNotEmpty ? f.name[0] : '?',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.major.isEmpty ? '학과 정보 없음' : f.major,
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 11.5,
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Symbols.check_circle
                          : Symbols.radio_button_unchecked,
                      fill: isSelected ? 1 : 0,
                      size: 22,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ManualTab extends StatelessWidget {
  const _ManualTab({
    required this.idCtrl,
    required this.nameCtrl,
    required this.error,
    required this.onChanged,
  });
  final TextEditingController idCtrl;
  final TextEditingController nameCtrl;
  final String? error;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: '학번',
            hintText: '8자리 숫자',
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: nameCtrl,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: '이름',
            filled: true,
            fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
