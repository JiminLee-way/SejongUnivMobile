import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/routing/menu_route_helper.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/core/demo/demo.dart';
import 'package:sejong_smart_campus/features/my/presentation/screens/my_screen.dart';
import 'package:sejong_smart_campus/features/student_id/presentation/providers/student_id_providers.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/domain/lucide_icon_map.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/menu_dispatcher.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/menu_providers.dart';
import 'package:sejong_smart_campus/features/menu/presentation/screens/menu_order_editor_screen.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_app_bar_shell.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';

/// "전체 서비스" 화면 — sjapp STUDENT_MAIN 메뉴 트리 미러.
///
/// 8 그룹 expandable + 검색바. 클릭은 모두 [MenuDispatcher]로 위임
/// (외부 핸드오프·내부 라우트 fallback 메시지 포함).
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.asDrawer = false, this.onClose});

  /// AppShell의 endDrawer로 띄울 때 true. AppBar 뒤로가기를 drawer 닫기로 대체.
  final bool asDrawer;

  /// drawer 닫기 콜백. AppShell이 자신의 `_scaffoldKey.currentState.closeEndDrawer`를
  /// 넘겨준다. ServicesScreen 자체가 Scaffold를 가지므로 내부 `Scaffold.of`로는
  /// 외부 endDrawer를 찾을 수 없어 콜백으로 위임. asDrawer=false면 null.
  final VoidCallback? onClose;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(studentMenuTreeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _open(SejongMenuItem item) async {
    // 우리 자체 네이티브 화면이 있는 메뉴는 dispatcher 우회. sjapp의 webview
    // 내부 라우트(`aca.*`, `inf.*`)를 url 패턴으로 식별.
    if (_routeInternally(item)) return;
    final dispatcher = ref.read(menuDispatcherProvider);
    final r = await dispatcher.dispatch(item);
    if (!mounted) return;
    showDispatchResult(context, r);
  }

  bool _routeInternally(SejongMenuItem item) {
    // 라우팅 로직은 [routeByMenuItem]에 위임 — home_screen 바로가기도 같은
    // helper를 사용해 url/key 기반으로 일관되게 push.
    return routeByMenuItem(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 사용자 편집 순서가 적용된 트리. 편집 안 했으면 sjapp 기본 순서 그대로.
    final treeAsync = ref.watch(sortedStudentMenuTreeProvider);
    // drawer 모드: AppShell이 이미 MeshBackground를 painting 중이고 Drawer는
    // 88% width surface 위에 깔리므로, 자체 MeshBackground를 또 paint하면
    // 5 RadialGradient × 2 layer로 GPU 낭비 + 그 위 BackdropFilter snapshot
    // 비용까지 누적되어 Galaxy S25 같은 고DPR 디바이스에서 렉. drawer 모드는
    // Drawer의 surface 단색 위에 그대로 콘텐츠를 그린다.
    // standalone push 모드는 AppShell route 아래에 있어 자체 mesh가 필요.
    final stackChild = Stack(
      children: [
        SafeArea(
          top: false,
          child: SejongRefresh(
            onRefresh: _onRefresh,
            topInset: mq.padding.top + 64,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: mq.padding.top + 64 + 8),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginMobile,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: widget.asDrawer
                        ? _DrawerProfileCard(onClose: widget.onClose)
                        : _SearchBar(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v.trim()),
                          ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                treeAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.marginMobile),
                      child: Text(
                        '메뉴를 불러오지 못했어요. 잠시 후 다시 시도해주세요.',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  data: (tree) => SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    sliver: SliverList.list(children: _buildSections(tree)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 120 + mq.padding.bottom),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: _ServicesAppBar(
            asDrawer: widget.asDrawer,
            onClose: widget.onClose,
          ),
        ),
      ],
    );

    final scaffold = Scaffold(
      backgroundColor: widget.asDrawer ? Colors.transparent : AppColors.surface,
      extendBodyBehindAppBar: true,
      body: widget.asDrawer ? stackChild : MeshBackground(child: stackChild),
    );

    if (widget.asDrawer && widget.onClose != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) => widget.onClose!(),
        child: scaffold,
      );
    }
    return scaffold;
  }

  List<Widget> _buildSections(List<SejongMenuItem> tree) {
    final q = _query.toLowerCase();
    if (q.isEmpty) {
      // 그룹 expandable + 단일 leaf 카드. "지원"·"설정"은 custom_menu_tree에서
      // top-level leaf로 끝에 주입되므로 [_SingleLeafCard]로 렌더.
      final widgets = <Widget>[];
      for (final node in tree.where((e) => e.visible && e.active)) {
        if (node.isLeaf) {
          widgets.add(_SingleLeafCard(item: node, onTap: _open));
        } else {
          widgets.add(_GroupTile(group: node, onLeafTap: _open));
        }
        widgets.add(const SizedBox(height: 10));
      }
      return widgets;
    }
    // 검색 모드 — 전체 leaf flatten 후 필터.
    final hits = <SejongMenuItem>[];
    void walk(SejongMenuItem n) {
      if (n.isLeaf &&
          n.visible &&
          n.active &&
          n.itemName.toLowerCase().contains(q)) {
        hits.add(n);
      }
      n.children?.forEach(walk);
    }

    tree.forEach(walk);
    if (hits.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              '"$_query"에 대한 결과가 없어요',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      for (final l in hits) ...[
        _LeafTile(item: l, onTap: _open),
        const SizedBox(height: 6),
      ],
    ];
  }
}

// ─── AppBar ────────────────────────────────────────────────────────────────

class _ServicesAppBar extends ConsumerWidget {
  const _ServicesAppBar({this.asDrawer = false, this.onClose});
  final bool asDrawer;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    // drawer 모드: BackdropFilter 없이 fake glass (불투명한 surface alpha +
    // hairline). drawer가 88% width 슬라이드 인할 때 매 프레임 backdrop
    // snapshot이 발생하는데, ServicesScreen은 10개 GlassCard + (AppShell
    // mesh가 비치므로) 입력 layer가 무거워 Galaxy S25 같은 고DPR 디바이스에서
    // 끊김. drawer 자체가 좁아 시각적 차이 미미.
    // standalone 모드: 진짜 BackdropFilter 유지하되 sigma 8로 절감.
    final hasUnread = ref.watch(combinedUnreadCountProvider) > 0;
    final bar = Container(
      height: top + 64,
      padding: EdgeInsets.only(top: top, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: asDrawer ? 0.92 : 0.78),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
      child: _barRow(context, hasUnread: hasUnread),
    );
    return asDrawer ? bar : GlassAppBarShell(sigma: 8, child: bar);
  }

  Widget _barRow(BuildContext context, {required bool hasUnread}) {
    return Row(
      children: [
        IconButton(
          // drawer 모드: 닫기(X), 풀스크린 모드: 뒤로가기(←).
          icon: Icon(
            asDrawer ? Symbols.close : Symbols.arrow_back,
            color: AppColors.onSurface,
          ),
          onPressed: () {
            if (asDrawer) {
              // onClose는 AppShell이 주입 — _scaffoldKey 기반 closeEndDrawer.
              // 폴백: Navigator.maybePop (drawer가 아닌 다른 진입 케이스).
              (onClose ?? () => Navigator.of(context).maybePop()).call();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        Expanded(
          child: Text(
            '전체 서비스',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // 알림함 — drawer 모드에서는 메인 Topbar의 알림 아이콘이 가려지므로
        // 전체 서비스에서도 동일 access 제공.
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Symbols.notifications,
                color: AppColors.onSurface,
              ),
              tooltip: '알림함',
              onPressed: () {
                final wasDrawer = asDrawer;
                final navigator = Navigator.of(context, rootNavigator: true);
                if (wasDrawer) onClose?.call();
                Future<void>.delayed(
                  Duration(milliseconds: wasDrawer ? 220 : 0),
                  () => navigator.push(slideRoute(const NotificationsScreen())),
                );
              },
            ),
            if (hasUnread)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        // 편집(연필) 버튼 — 그룹/leaf 순서 편집 화면 진입.
        // drawer 모드에서는 drawer를 먼저 닫고 root navigator에 push하지
        // 않으면 drawer 위에 push되어 closeEndDrawer 후에도 가려진 채 남는다.
        IconButton(
          icon: const Icon(Symbols.edit_note, color: AppColors.onSurface),
          tooltip: '메뉴 순서 편집',
          onPressed: () {
            final wasDrawer = asDrawer;
            final navigator = Navigator.of(context, rootNavigator: true);
            if (wasDrawer) onClose?.call();
            Future<void>.delayed(
              Duration(milliseconds: wasDrawer ? 220 : 0),
              () => navigator.push(
                MaterialPageRoute(
                  builder: (_) => const MenuOrderEditorScreen(),
                  fullscreenDialog: true,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── 검색바 ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.bodyMd,
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: '서비스 검색 (예: 시간표, 장학금, 도서관)',
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 12, right: 4),
            child: Icon(Symbols.search, color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

// ─── 그룹 + leaf 타일 ──────────────────────────────────────────────────────

class _GroupTile extends StatefulWidget {
  const _GroupTile({required this.group, required this.onLeafTap});
  final SejongMenuItem group;
  final ValueChanged<SejongMenuItem> onLeafTap;

  @override
  State<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<_GroupTile> {
  // 첫 진입에 8 그룹 × 평균 10 leaf = 80+ leaf가 한꺼번에 mount되면 Topbar
  // BackdropFilter가 매 프레임 그 영역을 다시 blur해야 해서 스크롤이 끊긴다.
  // default를 collapsed로 두고 사용자가 필요한 그룹만 펼치게 — 일반적인
  // 메뉴 UX와 일치.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final children = (widget.group.children ?? const <SejongMenuItem>[])
        .where((e) => e.visible && e.active)
        .toList();
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Row(
                children: [
                  Icon(
                    lucideToSymbol(
                      widget.group.iconClass,
                      fallback: Symbols.folder,
                    ),
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
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
                    '${children.length}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
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
          if (_expanded) ...[
            const SizedBox(height: 4),
            for (final c in children) ...[
              _LeafTile(item: c, onTap: widget.onLeafTap),
            ],
          ],
        ],
      ),
    );
  }
}

/// top-level leaf 단일 카드. "지원"·"설정" 처럼 그룹 없이 노출되는 항목을
/// _GroupTile과 비슷한 톤으로 그려 시각 일관성 유지. expand 없이 탭 즉시 라우팅.
class _SingleLeafCard extends StatelessWidget {
  const _SingleLeafCard({required this.item, required this.onTap});
  final SejongMenuItem item;
  final ValueChanged<SejongMenuItem> onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => onTap(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            children: [
              Icon(
                lucideToSymbol(item.iconClass, fallback: Symbols.label),
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.itemName,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Symbols.chevron_right, size: 22, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeafTile extends StatelessWidget {
  const _LeafTile({required this.item, required this.onTap});
  final SejongMenuItem item;
  final ValueChanged<SejongMenuItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => onTap(item),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest.withValues(
                    alpha: 0.85,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  lucideToSymbol(item.iconClass, fallback: Symbols.label),
                  size: 18,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.itemName,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  _callTypeIcon(item.callType),
                  size: 16,
                  color: AppColors.outline.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Lucide → Material Symbols 매핑은 모두 [lucideToSymbol] (lucide_icon_map.dart)
// 한 곳에서 관리. quick action picker / 메인 그리드 / 전체 서비스가 같은
// 매핑을 공유해 동일 메뉴에 동일 아이콘이 나오도록 한다.

IconData _callTypeIcon(String callType) {
  return switch (callType) {
    'EXTERNAL_BROWSER' => Symbols.open_in_new,
    'INAPP_BROWSER' => Symbols.open_in_browser,
    'APPLINK' => Symbols.smartphone,
    'WEBVIEW' => Symbols.chevron_right,
    _ => Symbols.chevron_right,
  };
}

// ─── Drawer 모드 상단 — 사용자 카드 (검색바 대체) ──────────────────────────

/// drawer 모드의 상단에 검색바 대신 표시되는 작은 사용자 카드.
///
/// 작은 프로필 사진 + 이름 + (학번·학과) 한 줄. tap → drawer 닫고 MyScreen 진입.
class _DrawerProfileCard extends ConsumerWidget {
  const _DrawerProfileCard({this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(displayUserProvider);
    // `.select((a) => a.value)`로 AsyncValue 인스턴스 변화는 무시하고 실제
    // 디코딩된 bytes만 추적 — 같은 사진이 그대로면 rebuild 안 함.
    final photoBytes = ref.watch(myPhotoProvider.select((a) => a.value));
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          // drawer 닫고 MyScreen으로. AppShell의 root navigator에 push.
          onClose?.call();
          Future<void>.delayed(const Duration(milliseconds: 220), () {
            if (!context.mounted) return;
            Navigator.of(
              context,
              rootNavigator: true,
            ).push(slideRoute(const MyScreen()));
          });
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              // 사진 — photos/me bytes. 없으면 silhouette.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE4E6), Color(0xFFFFD1D7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoBytes != null
                    ? Image.memory(
                        photoBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Icon(
                        Symbols.person,
                        size: 30,
                        fill: 1,
                        color: AppColors.primary.withValues(alpha: 0.55),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.username ?? '—',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user == null
                          ? '—'
                          : '${user.userId}  ·  ${user.departmentName}',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right,
                size: 20,
                color: AppColors.outline.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
