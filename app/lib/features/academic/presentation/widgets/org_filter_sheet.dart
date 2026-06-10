import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';

/// 학과/대학원 필터 bottom sheet. multi-select, 빈 = 전체.
Future<void> showOrgFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _OrgFilterSheet(),
  );
}

class _OrgFilterSheet extends ConsumerStatefulWidget {
  const _OrgFilterSheet();
  @override
  ConsumerState<_OrgFilterSheet> createState() => _OrgFilterSheetState();
}

class _OrgFilterSheetState extends ConsumerState<_OrgFilterSheet> {
  late Set<String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = Set<String>.from(ref.read(orgFilterProvider));
  }

  @override
  Widget build(BuildContext context) {
    final orgs = ref.watch(organizationTypesProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Symbols.filter_alt,
                      size: 20,
                      color: AppColors.primary,
                      fill: 1,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '학과 / 대학원 필터',
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _draft.isEmpty
                          ? null
                          : () => setState(_draft.clear),
                      child: Text(
                        '전체 해제',
                        style: AppTypography.labelMd.copyWith(
                          color: _draft.isEmpty
                              ? AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                )
                              : AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _draft.isEmpty
                      ? '아무 것도 선택하지 않으면 모든 학과 일정을 봐요'
                      : '${_draft.length}개 학과 선택됨',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: orgs.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (_, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('학과 목록을 불러오지 못했어요')),
                  ),
                  data: (list) => list.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('학과 목록이 비어 있어요')),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final o in list)
                                _OrgChip(
                                  org: o,
                                  selected: _draft.contains(o.name),
                                  onTap: () {
                                    setState(() {
                                      if (!_draft.add(o.name)) {
                                        _draft.remove(o.name);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    onPressed: () {
                      ref.read(orgFilterProvider.notifier).set(_draft);
                      Navigator.of(context).maybePop();
                    },
                    child: Text(
                      '적용',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
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

class _OrgChip extends StatelessWidget {
  const _OrgChip({
    required this.org,
    required this.selected,
    required this.onTap,
  });
  final OrganizationType org;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.full);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surface.withValues(alpha: 0.95),
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outline.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Symbols.check,
                size: 14,
                color: AppColors.onPrimary,
                fill: 1,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              org.name,
              style: AppTypography.labelMd.copyWith(
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
