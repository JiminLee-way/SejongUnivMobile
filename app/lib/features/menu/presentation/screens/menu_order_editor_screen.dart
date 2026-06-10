import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/menu/data/datasources/menu_order_storage.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/menu_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';

/// 메뉴 순서 편집기.
///
/// - 그룹 카드 자체를 위/아래로 drag해 순서 변경
/// - 카드를 펼치면 내부 leaf도 drag으로 reorder
/// - "저장"을 누를 때만 [menuOrderProvider]에 반영 → ServicesScreen 즉시 갱신
class MenuOrderEditorScreen extends ConsumerStatefulWidget {
  const MenuOrderEditorScreen({super.key});

  @override
  ConsumerState<MenuOrderEditorScreen> createState() =>
      _MenuOrderEditorScreenState();
}

class _MenuOrderEditorScreenState extends ConsumerState<MenuOrderEditorScreen> {
  /// 로컬 작업 사본. UI는 이걸 보고 그리고, 저장 시 provider로 commit.
  List<SejongMenuItem>? _groups;
  // groupId → 로컬 leaf 순서 (해당 그룹을 손댄 적 있을 때만 entry 있음).
  final Map<String, List<SejongMenuItem>> _leafOverrides = {};
  bool _saving = false;
  bool _dirty = false;

  void _ensureSeed(List<SejongMenuItem> baseTree) {
    if (_groups != null) return;
    _groups = baseTree.where((e) => e.visible && e.active).toList();
  }

  List<SejongMenuItem> _childrenOf(SejongMenuItem g) {
    final override = _leafOverrides[g.itemId];
    if (override != null) return override;
    return (g.children ?? const <SejongMenuItem>[])
        .where((e) => e.visible && e.active)
        .toList();
  }

  Future<void> _save() async {
    final groups = _groups;
    if (groups == null) return;
    setState(() => _saving = true);
    final groupOrder = groups.map((g) => g.itemId).toList();
    final leafOrder = <String, List<String>>{};
    for (final g in groups) {
      final override = _leafOverrides[g.itemId];
      if (override != null) {
        leafOrder[g.itemId] = override.map((c) => c.itemId).toList();
      }
    }
    try {
      await ref
          .read(menuOrderProvider.notifier)
          .save(MenuOrder(groupOrder: groupOrder, leafOrder: leafOrder));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('저장에 실패했어요: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('메뉴 순서를 저장했어요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('순서 초기화'),
        content: const Text('편집한 순서를 모두 지우고 sjapp 기본 순서로 되돌릴까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('초기화', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(menuOrderProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('초기화에 실패했어요: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 편집 base는 "사용자 순서가 이미 적용된" 트리(sorted) — 학술정보원 등 우리
    // 구조를 그대로 노출하면서, 편집기를 다시 열었을 때 직전에 저장한 순서가
    // 그대로 보이도록 한다. (customized는 순서 미적용이라 저장한 순서가 사라진
    // 것처럼 보였음.)
    final treeAsync = ref.watch(sortedStudentMenuTreeProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: treeAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                error: (_, _) => Center(
                  child: Text(
                    '메뉴를 불러오지 못했어요',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                data: (tree) {
                  _ensureSeed(tree);
                  final groups = _groups!;
                  return Padding(
                    padding: EdgeInsets.only(
                      top: mq.padding.top + 64 + 8,
                      bottom: 12 + mq.padding.bottom,
                    ),
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.marginMobile,
                        4,
                        AppSpacing.marginMobile,
                        16,
                      ),
                      buildDefaultDragHandles: false,
                      itemCount: groups.length,
                      onReorder: (oldIdx, newIdx) {
                        setState(() {
                          final list = [...groups];
                          if (newIdx > oldIdx) newIdx -= 1;
                          final moved = list.removeAt(oldIdx);
                          list.insert(newIdx, moved);
                          _groups = list;
                          _dirty = true;
                        });
                      },
                      proxyDecorator: (child, _, anim) =>
                          _DragProxyDecorator(animation: anim, child: child),
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        return Padding(
                          key: ValueKey('group_${g.itemId}'),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GroupEditCard(
                            index: i,
                            group: g,
                            children: _childrenOf(g),
                            onLeavesReorder: (next) {
                              setState(() {
                                _leafOverrides[g.itemId] = next;
                                _dirty = true;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _EditorAppBar(
                dirty: _dirty,
                saving: _saving,
                onSave: _save,
                onReset: _resetDefaults,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onReset,
  });
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: top + 64,
      padding: EdgeInsets.only(top: top, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Symbols.close, color: AppColors.onSurface),
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              '메뉴 순서 편집',
              style: AppTypography.headlineMd.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.refresh, color: AppColors.onSurface),
            tooltip: '기본 순서로 초기화',
            onPressed: saving ? null : onReset,
          ),
          TextButton(
            onPressed: (!dirty || saving) ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    '저장',
                    style: AppTypography.labelMd.copyWith(
                      color: dirty
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _GroupEditCard extends StatefulWidget {
  const _GroupEditCard({
    required this.index,
    required this.group,
    required this.children,
    required this.onLeavesReorder,
  });
  final int index;
  final SejongMenuItem group;
  final List<SejongMenuItem> children;
  final ValueChanged<List<SejongMenuItem>> onLeavesReorder;

  @override
  State<_GroupEditCard> createState() => _GroupEditCardState();
}

class _GroupEditCardState extends State<_GroupEditCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: widget.children.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Symbols.drag_indicator,
                        size: 22,
                        color: AppColors.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.group.itemName,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.children.length}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (widget.children.isNotEmpty)
                    Icon(
                      _expanded
                          ? Symbols.keyboard_arrow_up
                          : Symbols.keyboard_arrow_down,
                      size: 22,
                      color: AppColors.outline,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.children.isNotEmpty) ...[
            const Divider(height: 1),
            // 내부 leaf reorderable. shrinkWrap + NeverScrollable로 카드 안에 안전 배치.
            ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: widget.children.length,
              onReorder: (oldIdx, newIdx) {
                final list = [...widget.children];
                if (newIdx > oldIdx) newIdx -= 1;
                final moved = list.removeAt(oldIdx);
                list.insert(newIdx, moved);
                widget.onLeavesReorder(list);
              },
              proxyDecorator: (child, _, anim) =>
                  _DragProxyDecorator(animation: anim, child: child),
              itemBuilder: (context, i) {
                final c = widget.children[i];
                return _LeafEditRow(
                  key: ValueKey('leaf_${widget.group.itemId}_${c.itemId}'),
                  index: i,
                  item: c,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _LeafEditRow extends StatelessWidget {
  const _LeafEditRow({super.key, required this.index, required this.item});
  final int index;
  final SejongMenuItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(
                Symbols.drag_handle,
                size: 18,
                color: AppColors.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.itemName,
              style: AppTypography.labelMd.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// drag 중 살짝 떠올린 elevation + scale 효과.
class _DragProxyDecorator extends StatelessWidget {
  const _DragProxyDecorator({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.02 * t,
          child: Material(
            elevation: 6 * t,
            color: Colors.transparent,
            shadowColor: AppColors.ambientShadow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: child,
          ),
        );
      },
    );
  }
}
