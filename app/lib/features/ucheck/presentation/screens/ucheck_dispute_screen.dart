import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/shell/presentation/widgets/bottom_nav_insets.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_objection.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/ucheck_providers.dart';

/// 결석 cell 탭 시 ModalBottomSheet으로 진입.
///
/// 3 상태:
/// - 로드 중 → spinner
/// - 이미 제출됨 → readOnly (사유라벨 + 내용 + 답변)
/// - 미제출 → DropdownMenu(사유) + TextField(내용 500자) + 전송 버튼
///
/// 첨부파일은 V1에서 비활성화 placeholder (서버는 `objection_attach='[]'` 받음).
class UCheckDisputeScreen extends ConsumerStatefulWidget {
  const UCheckDisputeScreen({
    super.key,
    required this.lectureNo,
    required this.lectureWeek,
    required this.classNo,
    required this.attendType,
  });

  final int lectureNo;
  final int lectureWeek;
  final int classNo;

  /// 원래 출결 상태 — submitObjection.do에 그대로 전달. "3"=결석.
  final String attendType;

  @override
  ConsumerState<UCheckDisputeScreen> createState() =>
      _UCheckDisputeScreenState();
}

class _UCheckDisputeScreenState extends ConsumerState<UCheckDisputeScreen> {
  ObjectionCode? _selected;
  late final TextEditingController _detailController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _detailController = TextEditingController();
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null || _detailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사유와 내용을 모두 입력해주세요.')));
      return;
    }
    setState(() => _submitting = true);
    final repo = ref.read(ucheckRepositoryProvider);
    final ok = await repo.submitObjection(
      lectureNo: widget.lectureNo,
      lectureWeek: widget.lectureWeek,
      classNo: widget.classNo,
      attendType: widget.attendType,
      objectionCd: _selected!.code,
      objectionDetail: _detailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      ref.invalidate(ucheckDataProvider);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이의신청이 접수되었습니다')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('전송 실패 — 잠시 후 다시 시도해주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = ObjectionTarget(
      lectureNo: widget.lectureNo,
      lectureWeek: widget.lectureWeek,
      classNo: widget.classNo,
    );
    final asyncDetail = ref.watch(ucheckObjectionDetailProvider(target));

    // 시트 하단 inset:
    // - viewInsets.bottom : 키보드 올라왔을 때 키보드 높이
    // - BottomNavInsets   : AppShell 바텀 네비게이션(64+) 만큼 띄움
    //                       (사용자 요구: 제출 버튼이 nav bar 위에 보이도록)
    final navInset = BottomNavInsets.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard + navInset),
      child: SafeArea(
        top: false,
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Symbols.gavel, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('이의신청', style: AppTypography.headlineMd),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: asyncDetail.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          '정보를 불러오지 못했어요.\n$e',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      data: _buildContent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('전송'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ObjectionDetailResponse resp) {
    if (resp.result != 1 || resp.value == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '이의신청 정보를 가져오지 못했어요.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final value = resp.value!;
    final alreadySubmitted = (value.objectionDetail ?? '').isNotEmpty;

    if (alreadySubmitted) {
      return _ReadOnlyView(value: value);
    }

    final codes = resp.objectionCdList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '사유',
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in codes)
              ChoiceChip(
                label: Text(c.string),
                selected: _selected?.code == c.code,
                onSelected: (_) => setState(() => _selected = c),
                showCheckmark: false,
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: AppTypography.labelMd.copyWith(
                  color: _selected?.code == c.code
                      ? AppColors.primary
                      : AppColors.onSurface,
                  fontWeight: _selected?.code == c.code
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide(
                  color: _selected?.code == c.code
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                ),
                backgroundColor: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '상세 내용',
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _detailController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: '결석 사유를 자세히 적어주세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              const Icon(Symbols.attach_file, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '파일 첨부는 추후 지원 예정이에요',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyView extends StatelessWidget {
  const _ReadOnlyView({required this.value});
  final ObjectionDetailValue value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이미 제출된 이의신청',
          style: AppTypography.headlineMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '사유 코드: ${value.objectionCd ?? "-"}',
          style: AppTypography.labelMd,
        ),
        const SizedBox(height: 6),
        Text(
          '내용:',
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(value.objectionDetail ?? '', style: AppTypography.bodyMd),
        if ((value.objectionReply ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '답변:',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(value.objectionReply!, style: AppTypography.bodyMd),
        ],
      ],
    );
  }
}

/// 외부 호출 헬퍼.
Future<bool?> showUCheckDisputeSheet(
  BuildContext context, {
  required int lectureNo,
  required int lectureWeek,
  required int classNo,
  required String attendType,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => UCheckDisputeScreen(
      lectureNo: lectureNo,
      lectureWeek: lectureWeek,
      classNo: classNo,
      attendType: attendType,
    ),
  );
}
