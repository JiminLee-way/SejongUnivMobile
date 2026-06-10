import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/friends/domain/entities/friend_models.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 친구 추가 화면 — 홈과 동일한 글래스/메시 디자인 언어로 통일한 단일 스크롤.
///
/// 세 영역을 위에서 아래로:
///  1. **받은 친구 신청** — 들어온 신청을 수락/거절(있을 때만 노출).
///  2. **친구 찾기** — 이름 또는 학번 8자리로 검색. 검색 결과가 없으면 "아직
///     가입 안 한 친구" 로 보고 OS 공유 시트로 앱을 추천.
///  3. **초대 코드** — 24시간 유효 코드 발급/입력(redeem=양측 즉시 친구).
///
/// 검색 매칭은 모두 server-side HMAC blind index 기반으로 처리한다. 이름은
/// 암호화 저장이라 **정확한 전체 이름**만 매칭(부분/초성 불가).
const String _kAppName = '세종대역';
const String _kStoreUrl = ServiceUrls.androidStoreUrl;

String _buildInviteMessage(String code) =>
    '세종대생이라면 \'$_kAppName\' 앱 추천! 📚\n'
    '시간표 공유 · 열람실 예약 · 모바일 학생증까지 한 곳에서.\n\n'
    '내 초대코드: $code\n'
    '(앱 설치 → 시간표 ▸ 친구 ▸ 초대 코드에 입력하면 바로 친구가 돼요)\n\n'
    '다운로드 ▸ $_kStoreUrl';

class FriendAddScreen extends StatelessWidget {
  const FriendAddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.only(
                  top: SejongSubAppBar.heightFor(context) + 14,
                  left: AppSpacing.marginMobile,
                  right: AppSpacing.marginMobile,
                  bottom: 40 + MediaQuery.paddingOf(context).bottom,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: const [
                  _PendingRequestsSection(),
                  _SearchSection(),
                  SizedBox(height: AppSpacing.stackMd),
                  _InviteCodeSection(),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(title: '친구 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 공용 위젯 ──────────────────────────────────────────────────────────────

/// 홈 `_QuickActionsHeader` 와 같은 크림슨 vertical bar + 굵은 제목.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 16,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.surfaceTint],
              ),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: AppTypography.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$count',
        style: AppTypography.labelSm.copyWith(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/// 크림슨 그라데이션 캡슐 — 첫 글자 이니셜 아바타.
class _Avatar extends StatelessWidget {
  const _Avatar(this.name, {this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ch = name.trim().isNotEmpty ? name.trim().substring(0, 1) : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.surfaceTint],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        ch,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// 크림슨 그라데이션 1차 액션 버튼.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final radius = BorderRadius.circular(14);
    final spinSize = compact ? 13.0 : 16.0;
    final core = Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 18,
              vertical: compact ? 9 : 13,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.surfaceTint],
              ),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: spinSize,
                    height: spinSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: compact ? 15 : 18, color: Colors.white),
                if (busy || icon != null) SizedBox(width: compact ? 5 : 8),
                Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12.5 : 14,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: core) : core;
  }
}

/// 보조(고스트) 버튼 — 거절 등.
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.onTap,
    this.busy = false,
    this.fontSize = 12.5,
    this.center = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final double fontSize;

  /// 수락/거절처럼 동등한 액션 쌍으로 쓸 때 true — 라벨을 가운데 정렬하고
  /// (IntrinsicHeight stretch와 함께) 세로 중앙에 놓는다. 단독 사용(예: "다시 시도")
  /// 은 false로 두어 콘텐츠 크기를 유지.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: radius,
        child: Container(
          alignment: center ? Alignment.center : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: radius,
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );
}

// ─── 1. 받은 친구 신청 ───────────────────────────────────────────────────────

class _PendingRequestsSection extends ConsumerStatefulWidget {
  const _PendingRequestsSection();
  @override
  ConsumerState<_PendingRequestsSection> createState() =>
      _PendingRequestsSectionState();
}

class _PendingRequestsSectionState
    extends ConsumerState<_PendingRequestsSection> {
  final Set<String> _processing = {};

  Future<void> _respond(SupabaseFriendRequest req, bool accept) async {
    if (_processing.contains(req.friendshipId)) return;
    setState(() => _processing.add(req.friendshipId));
    try {
      final remote = ref.read(supabaseFriendsRemoteProvider);
      await remote.respondFriendRequest(
        friendshipId: req.friendshipId,
        accept: accept,
      );
      await refreshFriends(ref);
      if (!mounted) return;
      _toast(context, accept ? '${req.requesterName}님과 친구가 되었어요' : '신청을 거절했어요');
    } catch (e) {
      if (mounted) _toast(context, '처리 실패: $e');
    } finally {
      if (mounted) setState(() => _processing.remove(req.friendshipId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingFriendRequestsProvider);
    final reqs = async.value ?? const <SupabaseFriendRequest>[];
    if (reqs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: '받은 친구 신청', trailing: _CountBadge(reqs.length)),
        const SizedBox(height: 10),
        for (final r in reqs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RequestCard(
              req: r,
              busy: _processing.contains(r.friendshipId),
              onAccept: () => _respond(r, true),
              onDecline: () => _respond(r, false),
            ),
          ),
        const SizedBox(height: AppSpacing.stackMd),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.req,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });
  final SupabaseFriendRequest req;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if ((req.requesterDepartment ?? '').isNotEmpty) req.requesterDepartment!,
      _relativeTime(req.requestedAt),
    ].join(' · ');
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(req.requesterName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.requesterName.isEmpty ? '익명' : req.requesterName,
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 거절(고스트)·수락(그라데이션)을 동일 높이로 — IntrinsicHeight + stretch로
          // 짧은 거절 버튼이 수락 버튼 높이에 맞춰 늘어나고, 글자 크기(14)·정렬(가운데)
          // 도 통일해 한 쌍처럼 보이게 한다.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _GhostButton(
                    label: '거절',
                    busy: busy,
                    onTap: onDecline,
                    fontSize: 14,
                    center: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _GradientButton(
                    label: '수락',
                    icon: Symbols.check,
                    busy: busy,
                    onTap: onAccept,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 2. 친구 찾기 ────────────────────────────────────────────────────────────

class _SearchSection extends ConsumerStatefulWidget {
  const _SearchSection();
  @override
  ConsumerState<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends ConsumerState<_SearchSection> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  bool _searched = false;
  bool _error = false;
  bool _wasStudentId = false;
  String _lastQuery = '';
  List<FriendSearchHit> _hits = const [];
  final Set<String> _sentIds = {};
  String? _sendingId;
  bool _inviting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _busy) return;
    final isDigits = RegExp(r'^\d+$').hasMatch(q);
    if (isDigits && q.length != 8) {
      _toast(context, '학번은 8자리 숫자예요. 이름으로 찾으려면 한글 이름을 입력하세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _searched = true;
      _error = false;
      _wasStudentId = isDigits;
      _lastQuery = q;
      _hits = const [];
    });
    try {
      final remote = ref.read(supabaseFriendsRemoteProvider);
      final List<FriendSearchHit> hits;
      if (isDigits) {
        final hit = await remote.findByStudentId(q);
        hits = hit == null ? const [] : [hit];
      } else {
        hits = await remote.findByName(q);
      }
      if (!mounted) return;
      setState(() => _hits = hits);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hits = const [];
          _error = true;
        });
        _toast(context, '검색 중 오류가 발생했어요');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 입력이 마지막 검색어와 달라지면 이전 결과/오류/미가입 카드 정리 — 다른
  /// 사람을 입력 중인데 옛 결과(특히 '못 찾았어요' 카드)가 남아있지 않게.
  void _onQueryChanged(String v) {
    if (_searched && v.trim() != _lastQuery) {
      setState(() {
        _searched = false;
        _error = false;
        _hits = const [];
      });
    }
  }

  Future<void> _sendRequest(FriendSearchHit hit) async {
    if (_sendingId != null) return;
    setState(() => _sendingId = hit.userId);
    try {
      final remote = ref.read(supabaseFriendsRemoteProvider);
      await remote.sendFriendRequest(hit.userId);
      await refreshFriends(ref);
      if (!mounted) return;
      setState(() => _sentIds.add(hit.userId));
      _toast(context, '${hit.maskedName}님에게 친구 신청을 보냈어요');
    } catch (e) {
      if (mounted) _toast(context, '신청 실패: $e');
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  Future<void> _recommendApp() async {
    if (_inviting) return;
    setState(() => _inviting = true);
    String? code;
    try {
      code = await ref.read(supabaseFriendsRemoteProvider).issueInviteCode();
    } catch (e) {
      if (mounted) {
        _toast(context, '초대 코드 발급에 실패했어요: $e');
        setState(() => _inviting = false);
      }
      return;
    }
    final msg = _buildInviteMessage(code);
    try {
      await SharePlus.instance.share(
        ShareParams(text: msg, subject: '$_kAppName 초대'),
      );
    } catch (_) {
      // 공유 시트 사용 불가 단말 — 클립보드 폴백.
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) _toast(context, '초대 메시지를 복사했어요. 친구에게 붙여넣어 보내세요!');
    }
    if (mounted) setState(() => _inviting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: '친구 찾기'),
        const SizedBox(height: 10),
        GlassCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.search,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _search(),
                style: AppTypography.bodyMd,
                decoration: InputDecoration(
                  hintText: '이름 또는 학번 8자리',
                  hintStyle: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  prefixIcon: const Icon(
                    Symbols.search,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                  suffixIcon: IconButton(
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(
                            Symbols.arrow_forward,
                            size: 20,
                            color: AppColors.primary,
                          ),
                    onPressed: _busy ? null : _search,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow.withValues(
                    alpha: 0.85,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Symbols.lock,
                    size: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '정확한 이름·학번으로만 찾을 수 있어요. 학번·이름은 평문 저장 안 됨(HMAC).',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 18),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ] else if (_hits.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (var i = 0; i < _hits.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ResultRow(
                    hit: _hits[i],
                    fallbackSubtitle: _wasStudentId ? '학번 $_lastQuery' : null,
                    sent: _sentIds.contains(_hits[i].userId),
                    sending: _sendingId == _hits[i].userId,
                    onSend: () => _sendRequest(_hits[i]),
                  ),
                ],
              ] else if (_error) ...[
                const SizedBox(height: 16),
                _SearchErrorRow(onRetry: _search),
              ] else if (_searched) ...[
                const SizedBox(height: 16),
                _NotFoundInvite(
                  query: _lastQuery,
                  busy: _inviting,
                  onRecommend: _recommendApp,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.hit,
    required this.fallbackSubtitle,
    required this.sent,
    required this.sending,
    required this.onSend,
  });
  final FriendSearchHit hit;
  final String? fallbackSubtitle;
  final bool sent;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final subtitle = (hit.department != null && hit.department!.isNotEmpty)
        ? hit.department!
        : (fallbackSubtitle ?? '세종대 재학생');
    return InnerGlassPanel(
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _Avatar(hit.maskedName, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.maskedName.isEmpty ? '비공개' : hit.maskedName,
                  style: AppTypography.headlineMd.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (sent)
            const _SentChip()
          else
            _GradientButton(
              label: '신청',
              icon: Symbols.person_add,
              busy: sending,
              expand: false,
              compact: true,
              onTap: onSend,
            ),
        ],
      ),
    );
  }
}

class _SentChip extends StatelessWidget {
  const _SentChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.check, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '신청됨',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 검색 실패(네트워크/RPC 오류) — "못 찾았어요"(미가입)와 구분. 재시도만 안내.
class _SearchErrorRow extends StatelessWidget {
  const _SearchErrorRow({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.cloud_off,
            size: 18,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '검색에 실패했어요. 네트워크를 확인하고 다시 시도해 주세요.',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _GhostButton(label: '다시 시도', onTap: onRetry),
        ],
      ),
    );
  }
}

/// 검색 결과 없음 → 미가입 친구로 보고 앱 추천 CTA.
class _NotFoundInvite extends StatelessWidget {
  const _NotFoundInvite({
    required this.query,
    required this.busy,
    required this.onRecommend,
  });
  final String query;
  final bool busy;
  final VoidCallback onRecommend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.surfaceTint.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
            child: const Icon(
              Symbols.person_search,
              size: 26,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '\'$query\' 님을 찾지 못했어요',
            textAlign: TextAlign.center,
            style: AppTypography.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '아직 $_kAppName 에 가입하지 않은 친구일 수 있어요.\n앱을 추천하고 초대 코드를 함께 보내보세요!',
            textAlign: TextAlign.center,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _GradientButton(
            label: '앱 추천하기',
            icon: Symbols.ios_share,
            busy: busy,
            onTap: onRecommend,
          ),
        ],
      ),
    );
  }
}

// ─── 3. 초대 코드 ────────────────────────────────────────────────────────────

class _InviteCodeSection extends ConsumerStatefulWidget {
  const _InviteCodeSection();
  @override
  ConsumerState<_InviteCodeSection> createState() => _InviteCodeSectionState();
}

class _InviteCodeSectionState extends ConsumerState<_InviteCodeSection> {
  final _redeemCtrl = TextEditingController();
  String? _issuedCode;
  bool _issuing = false;
  bool _redeeming = false;

  @override
  void dispose() {
    _redeemCtrl.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    if (_issuing) return;
    setState(() => _issuing = true);
    try {
      final code = await ref
          .read(supabaseFriendsRemoteProvider)
          .issueInviteCode();
      if (mounted) setState(() => _issuedCode = code);
    } catch (e) {
      if (mounted) _toast(context, '코드 발급 실패: $e');
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  Future<void> _shareIssued() async {
    final code = _issuedCode;
    if (code == null) return;
    final msg = _buildInviteMessage(code);
    try {
      await SharePlus.instance.share(
        ShareParams(text: msg, subject: '$_kAppName 초대'),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) _toast(context, '초대 메시지를 복사했어요');
    }
  }

  Future<void> _redeem() async {
    final code = _redeemCtrl.text.trim().toUpperCase();
    if (code.isEmpty || _redeeming) return;
    FocusScope.of(context).unfocus();
    setState(() => _redeeming = true);
    try {
      final remote = ref.read(supabaseFriendsRemoteProvider);
      await remote.redeemInviteCode(code);
      await refreshFriends(ref);
      if (!mounted) return;
      _redeemCtrl.clear();
      _toast(context, '친구가 추가되었어요');
    } catch (e) {
      if (mounted) _toast(context, '코드 사용 실패: $e');
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: '초대 코드'),
        const SizedBox(height: 10),
        // 내 코드 발급
        GlassCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Symbols.qr_code_2,
                    color: AppColors.primary,
                    size: 20,
                    fill: 1,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '내 초대 코드',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_issuedCode == null)
                _GradientButton(
                  label: _issuing ? '발급 중...' : '코드 발급',
                  icon: Symbols.add_link,
                  busy: _issuing,
                  onTap: _issue,
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Center(
                    child: SelectableText(
                      _issuedCode!,
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '24시간 유효 · 친구가 입력하면 즉시 양쪽 친구 등록',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                _GradientButton(
                  label: '코드 공유하기',
                  icon: Symbols.ios_share,
                  onTap: _shareIssued,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 받은 코드 입력
        GlassCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Symbols.login, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '받은 코드 입력',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _redeemCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(8),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                onSubmitted: (_) => _redeem(),
                textAlign: TextAlign.center,
                style: AppTypography.headlineMd.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5,
                  fontSize: 20,
                ),
                decoration: InputDecoration(
                  hintText: '8자리 코드',
                  hintStyle: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    fontSize: 16,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow.withValues(
                    alpha: 0.85,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _GradientButton(
                label: _redeeming ? '확인 중...' : '친구 등록',
                icon: Symbols.group_add,
                busy: _redeeming,
                onTap: _redeem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
}
