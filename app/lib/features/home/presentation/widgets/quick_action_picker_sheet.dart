import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/home/domain/entities/quick_action.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/quick_actions_providers.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/domain/lucide_icon_map.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/menu_providers.dart';

/// "+" 슬롯 탭 시 호출. 전체 서비스의 모든 leaf 항목 + 가상 키를 표시,
/// 추가 가능한 항목을 사용자가 골라 바로가기에 추가.
Future<void> showQuickActionPickerSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PickerSheet(),
  );
}

class _PickerSheet extends ConsumerWidget {
  const _PickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final treeAsync = ref.watch(sortedStudentMenuTreeProvider);
    final currentKeysAsync = ref.watch(quickActionsProvider);
    final currentKeys = currentKeysAsync.value ?? const <String>[];
    final atMax = currentKeys.length >= kQuickActionsMaxCount;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '바로가기 추가',
                      style: AppTypography.headlineMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${currentKeys.length}/$kQuickActionsMaxCount',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Symbols.close),
                    ),
                  ],
                ),
              ),
              if (atMax)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '바로가기는 최대 $kQuickActionsMaxCount개까지 추가할 수 있어요. '
                    '먼저 사용 안 하는 항목을 ✕로 지운 뒤 다시 시도해보세요.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: treeAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('메뉴를 불러오지 못했어요', style: AppTypography.bodyMd),
                    ),
                  ),
                  data: (tree) => _ItemList(
                    tree: tree,
                    currentKeys: currentKeys,
                    atMax: atMax,
                    scrollController: scrollController,
                  ),
                ),
              ),
              SizedBox(height: mq.padding.bottom),
            ],
          ),
        );
      },
    );
  }
}

class _ItemList extends ConsumerWidget {
  const _ItemList({
    required this.tree,
    required this.currentKeys,
    required this.atMax,
    required this.scrollController,
  });
  final List<SejongMenuItem> tree;
  final List<String> currentKeys;
  final bool atMax;
  final ScrollController scrollController;

  /// 메뉴 트리 + registry-only(tab switch 등) 키를 모두 flatten.
  List<_PickerEntry> _collect() {
    final entries = <_PickerEntry>[];
    final seen = <String>{};

    // 1) registry에 있는 키 우선 (탭 전환 가상 키 포함). 우리가 노출하고 싶은
    // 순서대로.
    for (final entry in kQuickActionRegistry.entries) {
      if (seen.add(entry.key)) {
        entries.add(
          _PickerEntry(
            key: entry.key,
            label: entry.value.label,
            icon: entry.value.icon,
          ),
        );
      }
    }

    // 2) 메뉴 트리의 leaf 중 registry에 없는 것도 추가. label은 메뉴명,
    //    icon은 `iconClass`(Lucide) → Material Symbols 매핑(lucideToSymbol).
    //    url이 빈 GROUP은 isLeaf 가드에서 자동 배제, url 빈 leaf는 키 충돌
    //    방지로 skip.
    void walk(SejongMenuItem n) {
      if (n.isLeaf && n.visible && n.active && n.url.isNotEmpty) {
        if (seen.add(n.url)) {
          entries.add(
            _PickerEntry(
              key: n.url,
              label: n.itemName,
              icon: lucideToSymbol(n.iconClass, fallback: Symbols.apps),
            ),
          );
        }
      }
      for (final c in n.children ?? const <SejongMenuItem>[]) {
        walk(c);
      }
    }

    for (final g in tree) {
      walk(g);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = _collect();
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final e = entries[i];
        final alreadyAdded = currentKeys.contains(e.key);
        final disabled = alreadyAdded || atMax;
        return _PickerTile(
          entry: e,
          disabled: disabled,
          alreadyAdded: alreadyAdded,
          onTap: () async {
            HapticFeedback.lightImpact();
            await ref.read(quickActionsProvider.notifier).add(e.key);
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _PickerEntry {
  const _PickerEntry({
    required this.key,
    required this.label,
    required this.icon,
  });
  final String key;
  final String label;
  final IconData icon;
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.entry,
    required this.disabled,
    required this.alreadyAdded,
    required this.onTap,
  });
  final _PickerEntry entry;
  final bool disabled;
  final bool alreadyAdded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: disabled
                    ? AppColors.outline.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                entry.icon,
                size: 22,
                color: disabled
                    ? AppColors.onSurfaceVariant.withValues(alpha: 0.5)
                    : AppColors.primary,
                fill: 1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? AppColors.onSurfaceVariant.withValues(alpha: 0.6)
                      : AppColors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (alreadyAdded)
              const Icon(Symbols.check, size: 20, color: AppColors.primary)
            else if (!disabled)
              Icon(Symbols.add_circle, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
