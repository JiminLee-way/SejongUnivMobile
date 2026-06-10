import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/screens/friend_add_screen.dart';
import 'package:sejong_smart_campus/features/notifications/domain/entities/notification_models.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(inboxProvider);
    ref.invalidate(pendingFriendRequestsProvider);
    ref.invalidate(unreadCountProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final inboxAsync = ref.watch(combinedInboxProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: SejongRefresh(
                onRefresh: () => _onRefresh(ref),
                topInset: mq.padding.top + 64,
                child: inboxAsync.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (_, _) => _ErrorView(onRetry: () => _onRefresh(ref)),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _EmptyView();
                    }
                    return ListView.separated(
                      padding: EdgeInsets.only(
                        top: mq.padding.top + 64 + 16,
                        left: AppSpacing.marginMobile,
                        right: AppSpacing.marginMobile,
                        bottom: 120 + mq.padding.bottom,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return _Tile(
                          item: item,
                          onTap: () {
                            markNotificationRead(ref, item.id);
                            // 친구요청은 받은 신청 화면으로 이동해 수락/거절.
                            if (item.kind == NotificationKind.friendRequest) {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).push(slideRoute(const FriendAddScreen()));
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _AppBar(
                onMarkAllRead: () => markAllNotificationsRead(ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onMarkAllRead});
  final VoidCallback onMarkAllRead;
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
            icon: const Icon(Symbols.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '알림함',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onMarkAllRead,
            icon: const Icon(
              Symbols.done_all,
              size: 18,
              color: AppColors.primary,
            ),
            label: Text(
              '모두 읽음',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.onTap});
  final SejongNotificationItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassCard(
          borderRadius: AppRadius.lg,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: item.isRead
                      ? AppColors.outline.withValues(alpha: 0.4)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              item.category!,
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 10.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (item.sentAt != null)
                          Text(
                            _formatDate(item.sentAt!),
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: item.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (item.body != null && item.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.month}월 ${d.day}일';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.notifications_off,
            size: 56,
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            '받은 알림이 없어요',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.error,
            fill: 1,
            size: 36,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '알림을 불러오지 못했어요',
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
