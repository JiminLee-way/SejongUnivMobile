import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/menu_route_helper.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/home/domain/entities/quick_action.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/quick_actions_providers.dart';
import 'package:sejong_smart_campus/features/home/presentation/widgets/quick_action_picker_sheet.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/menu_providers.dart';

/// 홈 화면 바로가기 그리드. 일반 모드/편집 모드 모두 처리.
///
/// 일반 모드: 5열 GridView, 탭으로 라우팅
/// 편집 모드: `ReorderableBuilder` 통합 — 드래그-드롭 reflow, ✕ 배지로 삭제,
///   끝에 "+" 슬롯(15개 미만일 때).
/// 외곽은 [AnimatedSize]로 래핑 — 줄 수 변할 때 부드럽게 height 보간 → 아래
/// LibraryStatusStrip이 ListView 흐름에 따라 자연스럽게 미끄러져 이동.
class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  static const _cols = kQuickActionsMaxCols;
  static const _crossSpacing = 8.0;
  static const _mainSpacing = 12.0;

  /// 바로가기 라벨 기본 크기. 셀 높이 계산과 타일 라벨이 공유한다(단일 출처).
  /// labelSm 토큰 기본(12)과 일치 — 그리드 라벨이 과하게 커 보이지 않게.
  static const labelFontSize = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keysAsync = ref.watch(quickActionsProvider);
    final editMode = ref.watch(quickActionsEditModeProvider);
    // 메뉴 트리를 여기서 한 번만 watch — Tile 16개가 각각 watch하면 트리 fetch
    // 완료/변경 시 모든 Tile이 동시에 rebuild. 그리드 한 곳에서 resolve해
    // props로 내려보내면 트리 변동 1회 → 그리드 단일 rebuild.
    final treeAsync = ref.watch(sortedStudentMenuTreeProvider);
    final tree = treeAsync.asData?.value ?? const <SejongMenuItem>[];

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: keysAsync.when(
        loading: () => const SizedBox(height: 170),
        error: (_, _) => const SizedBox(height: 170),
        data: (keys) => _Grid(
          keys: keys,
          editMode: editMode,
          menuTree: tree,
          notifier: ref.read(quickActionsProvider.notifier),
          editNotifier: ref.read(quickActionsEditModeProvider.notifier),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.keys,
    required this.editMode,
    required this.menuTree,
    required this.notifier,
    required this.editNotifier,
  });
  final List<String> keys;
  final bool editMode;
  final List<SejongMenuItem> menuTree;
  final QuickActionsNotifier notifier;
  final QuickActionsEditModeNotifier editNotifier;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth -
                QuickActionsGrid._crossSpacing * (QuickActionsGrid._cols - 1)) /
            QuickActionsGrid._cols;
        // 셀 높이는 폭이 아니라 **콘텐츠**(아이콘 48 + 간격 8 + 라벨 1줄)에 맞춘다.
        // 기존 폭비례 aspect(clamp 0.72)는 넓은 화면에서 셀 하단에 ~20dp 사공간을
        // 남겨 "행간·그리드↔카드 여백이 과하게 넓다"는 인상의 주범이었다. textScaler를
        // 곱해 시스템 큰 글씨에서도 라벨이 잘리지 않고 높이가 함께 늘어난다(반응형).
        final labelLine =
            MediaQuery.textScalerOf(
              context,
            ).scale(QuickActionsGrid.labelFontSize) *
            (16 / 12); // labelSm 행간 배수(height 16 / size 12)
        final cellHeight = 48 + 8 + labelLine + 4; // 아이콘+간격+라벨+하단 숨통 4
        final aspect = cellWidth / cellHeight;

        final showPlus = editMode && keys.length < kQuickActionsMaxCount;

        // 일반 모드: 단순 GridView
        if (!editMode) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: keys.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: QuickActionsGrid._cols,
              mainAxisSpacing: QuickActionsGrid._mainSpacing,
              crossAxisSpacing: QuickActionsGrid._crossSpacing,
              childAspectRatio: aspect,
            ),
            itemBuilder: (context, i) => QuickActionTile(
              actionKey: keys[i],
              editMode: false,
              menuTree: menuTree,
              onLongPress: () {
                HapticFeedback.mediumImpact();
                editNotifier.enter();
              },
            ),
          );
        }

        // 편집 모드: ReorderableBuilder + ✕ 배지 + "+" 슬롯
        final allKeys = [...keys, if (showPlus) '__add__'];
        final lockedIndices = showPlus ? <int>[allKeys.length - 1] : <int>[];
        final children = <Widget>[
          for (var i = 0; i < allKeys.length; i++)
            _editChild(
              context: context,
              index: i,
              actionKey: allKeys[i],
              isAddSlot: allKeys[i] == '__add__',
            ),
        ];

        return ReorderableBuilder<String>(
          enableDraggable: true,
          longPressDelay: Duration.zero,
          lockedIndices: lockedIndices,
          feedbackScaleFactor: 1.1,
          dragChildBoxDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          onReorder: (reorderFn) {
            final reordered = reorderFn(allKeys);
            // "__add__" 제외하고 저장
            final newKeys = reordered.where((k) => k != '__add__').toList();
            notifier.setOrder(newKeys);
          },
          builder: (children) {
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: QuickActionsGrid._cols,
                mainAxisSpacing: QuickActionsGrid._mainSpacing,
                crossAxisSpacing: QuickActionsGrid._crossSpacing,
                childAspectRatio: aspect,
              ),
              children: children,
            );
          },
          children: children,
        );
      },
    );
  }

  Widget _editChild({
    required BuildContext context,
    required int index,
    required String actionKey,
    required bool isAddSlot,
  }) {
    if (isAddSlot) {
      return _AddSlot(
        key: const ValueKey('__add__'),
        onTap: () => showQuickActionPickerSheet(context),
      );
    }
    return Stack(
      key: ValueKey(actionKey),
      clipBehavior: Clip.none,
      children: [
        QuickActionTile(
          actionKey: actionKey,
          editMode: true,
          menuTree: menuTree,
        ),
        Positioned(
          top: -4,
          right: -4,
          child: _RemoveBadge(
            onTap: () {
              HapticFeedback.lightImpact();
              notifier.remove(actionKey);
            },
          ),
        ),
      ],
    );
  }
}

/// 단일 바로가기 타일. 일반 모드: 탭 시 라우팅, long-press 시 편집 진입.
/// 편집 모드: 탭/long-press 비활성, wiggle 애니메이션.
class QuickActionTile extends StatefulWidget {
  const QuickActionTile({
    super.key,
    required this.actionKey,
    required this.editMode,
    required this.menuTree,
    this.onLongPress,
  });
  final String actionKey;
  final bool editMode;
  final List<SejongMenuItem> menuTree;
  final VoidCallback? onLongPress;

  @override
  State<QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<QuickActionTile>
    with SingleTickerProviderStateMixin {
  bool _active = false;
  Timer? _holdTimer;
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.editMode) _wiggle.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant QuickActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editMode && !_wiggle.isAnimating) {
      _wiggle.repeat(reverse: true);
    } else if (!widget.editMode && _wiggle.isAnimating) {
      _wiggle.stop();
      _wiggle.value = 0;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _wiggle.dispose();
    super.dispose();
  }

  void _setActive(bool v) {
    if (!mounted) return;
    setState(() => _active = v);
  }

  void _handleTap() {
    if (widget.editMode) return;
    _holdTimer?.cancel();
    _setActive(true);
    _holdTimer = Timer(const Duration(milliseconds: 120), () {
      _setActive(false);
      _navigate();
    });
  }

  void _navigate() {
    final ctx = context;
    if (!ctx.mounted) return;
    final info = resolveQuickActionInfo(widget.actionKey, widget.menuTree);
    final ok = routeByKey(ctx, widget.actionKey);
    if (!ok) {
      showRouteUnavailable(ctx, info.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = resolveQuickActionInfo(widget.actionKey, widget.menuTree);
    final label = info.label;
    final icon = info.icon;

    final accent = _active ? AppColors.primary : AppColors.onSurfaceVariant;
    final labelColor = _active ? AppColors.primary : AppColors.onSurfaceVariant;

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.editMode ? null : (_) => _setActive(true),
      onTapCancel: widget.editMode ? null : () => _setActive(false),
      onTap: widget.editMode ? null : _handleTap,
      onLongPress: widget.editMode ? null : widget.onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _active
                    ? [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.4),
                      ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _active
                    ? AppColors.primary.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.75),
                width: _active ? 1.4 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _active
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : const Color(0x14000000),
                  blurRadius: _active ? 14 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 24, color: accent, fill: 1),
          ),
          const SizedBox(height: 8),
          // 라벨 기본 14dp. 5글자(예: 집현캠퍼스)는 5열 셀 폭(~66dp@411)을 살짝
          // 넘겨 잘릴 수 있어, FittedBox(scaleDown)로 **넘칠 때만** 미세 축소해
          // 맞춘다 — 대부분 14dp 그대로, 가장 긴 라벨만 한 칸 줄어들고 클리핑은 0.
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: AppTypography.labelSm.copyWith(
              fontSize: QuickActionsGrid.labelFontSize,
              color: labelColor,
              fontWeight: _active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(label, maxLines: 1, softWrap: false),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.editMode) return tile;
    // 편집 모드: 작은 wiggle (좌우 ±1.5deg)
    return AnimatedBuilder(
      animation: _wiggle,
      builder: (_, child) {
        final t = (_wiggle.value * 2) - 1; // -1..1
        return Transform.rotate(angle: t * 0.026, child: child);
      },
      child: tile,
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(Symbols.close, size: 14, color: Colors.white),
      ),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: Icon(Symbols.add, size: 26, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '추가',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm.copyWith(
              fontSize: QuickActionsGrid.labelFontSize,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
