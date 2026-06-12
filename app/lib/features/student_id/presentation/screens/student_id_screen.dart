import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/core/demo/demo.dart';
import 'package:sejong_smart_campus/features/auth/domain/entities/sejong_user.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sejong_smart_campus/features/student_id/data/datasources/s1pass_native.dart';
import 'package:sejong_smart_campus/features/student_id/presentation/providers/s1pass_providers.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/library/presentation/providers/library_providers.dart';
import 'package:sejong_smart_campus/features/student_id/data/datasources/secure_screen.dart';
import 'package:sejong_smart_campus/features/student_id/presentation/providers/student_id_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/official_brand_logo.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';

/// 학생증 화면.
///
/// 구성:
///   1) 학생증 카드 — 좌측 사진, 우측 학번/학과/이름 + 세종대 로고
///   2) QR 카드 — 도서관 게이트 / 도서관 대출용 QR 토글 + 새로고침
class StudentIdScreen extends ConsumerStatefulWidget {
  const StudentIdScreen({super.key});

  @override
  ConsumerState<StudentIdScreen> createState() => _StudentIdScreenState();
}

class _StudentIdScreenState extends ConsumerState<StudentIdScreen> {
  /// sjapp QR payload의 `timestamp` 필드와 동일 — millisecondsSinceEpoch.
  int _qrTimestamp = DateTime.now().millisecondsSinceEpoch;

  /// 사용자가 명시 새로고침을 누른 횟수 (payload의 refreshKey와 1:1).
  int _refreshKey = 0;

  /// QR 유효 시간 — 공식 웹과 동일한 약 60초 주기로 서버 QR을 재발급.
  static const _qrLifetime = Duration(seconds: 60);
  DateTime _qrIssuedAt = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 학생증 표시 중에는 스크린샷/녹화/최근앱 미리보기 차단.
    SecureScreen.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining().isNegative) {
        _refreshQr();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _ticker?.cancel();
    super.dispose();
  }

  Duration _remaining() =>
      _qrIssuedAt.add(_qrLifetime).difference(DateTime.now());

  void _refreshQr() {
    setState(() {
      _qrTimestamp = DateTime.now().millisecondsSinceEpoch;
      _refreshKey++;
      _qrIssuedAt = DateTime.now();
    });
  }

  /// 서버 `/qr/generate`에 보낼 평문 payload JSON. 공식 웹이 보내는 것과 동일한
  /// 키 순서·필드. 서버는 이 평문을 암호화한 토큰을 QR PNG로 렌더해 돌려준다.
  String _buildQrPayload(SejongUser user) {
    return jsonEncode({
      'userId': user.userId,
      'name': user.username,
      'role': user.roles.isNotEmpty ? user.roles.first : 'STUDENT',
      'timestamp': _qrTimestamp,
      'refreshKey': _refreshKey,
    });
  }

  /// Pull-to-refresh — QR 갱신을 트리거. 실제 서버 연동 시 학생 정보까지
  /// 재요청하도록 확장.
  Future<void> _onRefresh() async {
    _refreshQr();
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;
    final user = ref.watch(currentUserProvider); // 실계정 — QR/토큰용
    final displayUser = ref.watch(displayUserProvider); // 데모면 가짜 사용자 표시
    final demo = ref.watch(demoModeProvider);
    final photoAsync = ref.watch(myPhotoProvider);
    // AuthGate가 미인증 사용자를 LoginScreen으로 보내므로 user는 통상 non-null.
    // 부트스트랩 도중·logout 직후의 짧은 frame을 위해 placeholder는 유지.
    final name = displayUser?.username ?? '—';
    final studentNumber = displayUser?.userId ?? '—';
    final department = displayUser?.departmentName ?? '—';
    final cohort = displayUser == null
        ? '—'
        : '${displayUser.userId.substring(0, 2)}학번';
    final validUntil = demo ? '2100.12.31' : '2027.02.28';
    final photoBytes = photoAsync.value;
    // QR은 표시용 데모 사용자가 아니라 실계정으로 인코딩 → 실제 게이트 인증 동작.
    final qrPayload = user == null ? '' : _buildQrPayload(user);
    // 서버가 payload를 암호화해 렌더한 QR PNG를 받아온다. payload가 비면
    // (부트스트랩/logout 프레임) 호출하지 않는다.
    //
    // payload는 갱신(만료/명시 새로고침) 때만 바뀌므로 평소 1초 틱 재빌드로는
    // 같은 family 키 → 캐시된 AsyncData를 그대로 받아 깜빡임이 없다. 갱신 순간엔
    // 새 키가 로딩 상태가 되어 스피너를 보여준다 — **직전 QR은 이미 만료됐으므로**
    // 그대로 노출하면(stale) 게이트가 ~60초 지난 토큰을 읽어 실패할 수 있어서다.
    // (asData?.value는 에러를 rethrow하지 않는 안전 접근.)
    final qrAsync = qrPayload.isEmpty
        ? null
        : ref.watch(qrImageProvider(qrPayload));
    final qrDisplayBytes = qrAsync?.asData?.value;
    final qrHasError = qrAsync?.hasError ?? false;
    final qrLoading = qrAsync?.isLoading ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            // SejongRefresh로 감싸야 BouncingScrollPhysics의 오버스크롤이
            // pull-to-refresh로 흡수됨. 빠지면 짧은 콘텐츠에서 "탁!"하고
            // 스프링백되는 점프 발생.
            child: SejongRefresh(
              onRefresh: _onRefresh,
              topInset: kSejongAppBarInset(context),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: topPad + 64 + 24,
                  left: AppSpacing.marginMobile,
                  right: AppSpacing.marginMobile,
                  bottom: 120 + botPad,
                ),
                // Android: ClampingScrollPhysics (platform default) — BouncingScrollPhysics는
                // 콘텐츠 끝에서 스프링백을 일으켜 맨 위로 튀는 현상이 생긴다.
                // AlwaysScrollable 단독 사용으로 pull-to-refresh는 여전히 작동.
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _IdCard(
                      name: name,
                      studentNumber: studentNumber,
                      department: department,
                      cohort: cohort,
                      validUntil: validUntil,
                      photoBytes: photoBytes,
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    _QrCard(
                      imageBytes: qrDisplayBytes,
                      isLoading: qrLoading,
                      hasError: qrHasError,
                      remaining: _remaining(),
                      onRefresh: _refreshQr,
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    const _LoanInfoCard(),
                    const SizedBox(height: AppSpacing.stackMd),
                    // S1Pass NFC 상태 chip — 학생증 카드 묶음 최하단.
                    // 도서대출 현황 카드 밑, 화면 끝 여백 직전.
                    const _NfcStatusChip(),
                  ],
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.topCenter,
            child: _StudentIdAppBar(),
          ),
        ],
      ),
    );
  }
}

// ─── AppBar ──────────────────────────────────────────────────────────────────

class _StudentIdAppBar extends StatelessWidget {
  const _StudentIdAppBar();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: top + 64,
      padding: EdgeInsets.only(
        top: top,
        left: AppSpacing.marginMobile,
        right: AppSpacing.marginMobile,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ambientShadow,
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '모바일 학생증',
              style: AppTypography.headlineMd.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ID Card ─────────────────────────────────────────────────────────────────

class _IdCard extends StatelessWidget {
  const _IdCard({
    required this.name,
    required this.studentNumber,
    required this.department,
    required this.cohort,
    required this.validUntil,
    required this.photoBytes,
  });

  final String name;
  final String studentNumber;
  final String department;
  final String cohort;
  final String validUntil;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // 우상단 워터마크 로고 (옅게)
          Positioned(
            top: -16,
            right: -16,
            child: Opacity(
              opacity: 0.06,
              child: OfficialBrandLogo(
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 라벨 — Student ID
              Row(
                children: [
                  Text(
                    'STUDENT ID',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  // 세종대 로고 (우상단)
                  const OfficialBrandLogo(
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 본문 — 사진 + 정보
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: name, photoBytes: photoBytes),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 학번
                        Text(
                          studentNumber,
                          style: AppTypography.timer.copyWith(
                            fontSize: 22,
                            color: AppColors.onSurface,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 학과
                        Text(
                          department,
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // 이름 + 학번 라벨
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              name,
                              style: AppTypography.headlineLgMobile.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                cohort,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // 구분선
              Container(
                height: 1,
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              // 캠퍼스 / 기간 정보
              Row(
                children: [
                  Expanded(
                    child: _MetaItem(label: '캠퍼스', value: '세종대학교'),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    child: _MetaItem(label: '유효기간', value: validUntil),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoBytes});

  final String name;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 124,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE4E6), Color(0xFFFFD1D7)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 실 학생 사진 (photos/me) — 없으면 silhouette fallback.
          if (photoBytes != null)
            Positioned.fill(
              child: Image.memory(
                photoBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  Symbols.person,
                  size: 76,
                  fill: 1,
                  color: AppColors.primary.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR Card ─────────────────────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.imageBytes,
    required this.isLoading,
    required this.hasError,
    required this.remaining,
    required this.onRefresh,
  });

  /// 서버가 렌더해 돌려준 QR PNG bytes. null이면 (로딩 전/에러/미로그인)
  /// 로딩 스피너·에러·silhouette로 대체.
  final Uint8List? imageBytes;

  /// 첫 QR을 받아오는 중인지 — 표시할 이전 이미지가 없을 때만 스피너.
  final bool isLoading;

  /// 서버 호출 실패 — stale QR 대신 재시도 안내를 보여준다.
  final bool hasError;
  final Duration remaining;
  final VoidCallback onRefresh;

  String _formatRemaining() {
    final secs = remaining.inSeconds.clamp(0, 99).toString().padLeft(2, '0');
    return '${secs}s';
  }

  double _progress() {
    const total = 60.0; // 공식 웹과 동일 — 약 60초 주기
    final remain = remaining.inMilliseconds / 1000.0;
    return (remain / total).clamp(0.0, 1.0);
  }

  /// QR 표시 영역. 우선순위: 에러 > 이미지(직전 성공 포함) > 로딩 > silhouette.
  Widget _buildQrContent() {
    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.qr_code_2,
              size: 64,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              'QR을 불러오지 못했어요\n새로고침을 눌러주세요',
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }
    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        width: 200,
        height: 200,
        fit: BoxFit.contain,
        gaplessPlayback: true, // 갱신 시 이전 프레임 유지 — 깜빡임 방지
        filterQuality: FilterQuality.none, // QR은 또렷한 픽셀 경계가 중요
      );
    }
    if (isLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.primary,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Symbols.qr_code_2,
        size: 80,
        color: AppColors.outline.withValues(alpha: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress();
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(
                Symbols.qr_code_2,
                size: 18,
                color: AppColors.primary,
                fill: 1,
              ),
              const SizedBox(width: 8),
              Text(
                'QR',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '도서관 게이트 · 도서 대출',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // QR
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: _buildQrContent(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 만료 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: progress < 0.3
                          ? [AppColors.primary, AppColors.primary]
                          : const [AppColors.primary, AppColors.surfaceTint],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 남은 시간 + 새로고침
          Row(
            children: [
              const Icon(
                Symbols.timer,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '남은 시간 ',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                _formatRemaining(),
                style: AppTypography.labelMd.copyWith(
                  color: progress < 0.3
                      ? AppColors.primary
                      : AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              _RefreshButton(onTap: onRefresh),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _handleTap() {
    _spin.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                offset: const Offset(0, 1),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spin,
                child: const Icon(
                  Symbols.refresh,
                  size: 16,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '새로고침',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 도서 대출 위젯 — /secureapi/library/loan-info ─────────────────────────

class _LoanInfoCard extends ConsumerWidget {
  const _LoanInfoCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loanInfoProvider);
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          const Icon(
            Symbols.menu_book,
            size: 22,
            fill: 1,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Text(
            '도서 대출 현황',
            style: AppTypography.labelMd.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          async.when(
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: AppColors.primary,
              ),
            ),
            error: (_, _) => Text(
              '—',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            data: (info) => Row(
              children: [
                _LoanBadge(label: '대출', value: info.loanCount),
                const SizedBox(width: 12),
                _LoanBadge(
                  label: '연체',
                  value: info.overDueCount,
                  highlight: info.overDueCount > 0,
                ),
                const SizedBox(width: 12),
                _LoanBadge(label: '예약', value: info.reserveCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanBadge extends StatelessWidget {
  const _LoanBadge({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final int value;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: AppTypography.labelMd.copyWith(
            fontSize: 16,
            color: highlight ? AppColors.primary : AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// QR은 서버(/secureapi/qr/generate)가 payload를 암호화해 렌더한 PNG를 그대로
// 표시한다 — 클라이언트 직접 렌더(qr_flutter)는 게이트가 인식 못 해 폐기.
// 자세한 배경은 SejongQrRemote 참고.

// ─── S1Pass NFC 상태 chip ────────────────────────────────────────────────

/// 학생증 카드 아래에 한 줄짜리 상태 chip — sjapp 로그인 직후 native가 자동으로
/// cardNo 저장 + ForegroundService 시작. 사용자는 이 chip만 보고 작동 여부 판단.
///
/// 5가지 상태:
/// - ready: NFC ON + service 실행 중 → 초록 "NFC 출입 가능"
/// - notRunning: 그 외 (재시작 필요) → 회색 "준비 중"
/// - nfcOff: NFC 토글 꺼짐 → 주황 "NFC 꺼짐 — 설정에서 켜주세요"
/// - noNfc: 하드웨어 없음 → 회색 "NFC 미지원"
/// - noCard: cardNo 없음 (로그아웃 상태) → 회색 "로그인 필요"
class _NfcStatusChip extends ConsumerStatefulWidget {
  const _NfcStatusChip();
  @override
  ConsumerState<_NfcStatusChip> createState() => _NfcStatusChipState();
}

class _NfcStatusChipState extends ConsumerState<_NfcStatusChip>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // startForegroundService()는 비동기라 provider 첫 조회 시 isRunning이 아직
    // false일 수 있다. 1초 뒤 재조회로 타이밍 경쟁을 해소.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) ref.invalidate(s1passStatusProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 사용자가 NFC 설정 다녀와서 돌아왔을 때 status 자동 refresh.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(s1passStatusProvider);
    }
  }

  /// notRunning 상태에서 탭 — POST_NOTIFICATIONS 권한 재요청 후 서비스 재시도.
  Future<void> _retryService() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return;
      }
      await Permission.notification.request();
    }
    await S1PassNative.startService();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) ref.invalidate(s1passStatusProvider);
  }

  /// 배터리 고지 배너 탭 — 배터리 최적화 제외 다이얼로그를 띄운다. 돌아오면
  /// (resume) status가 자동 invalidate되지만, 즉시성을 위해 한 번 더 invalidate.
  Future<void> _requestBatteryUnrestricted() async {
    if (!Platform.isAndroid) return;
    await Permission.ignoreBatteryOptimizations.request();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) ref.invalidate(s1passStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(s1passStatusProvider);
    final status = async.value;
    final (label, icon, color) = _resolve(status?.ui);
    final tappable = status?.ui == S1PassUiState.notRunning;
    // NFC가 의미 있는 상태(하드웨어 있음 + cardNo 있음)인데 배터리 제한 없음이 안
    // 돼있으면 → 백그라운드 동작 보장 안 됨 고지. nfcOff/notRunning/ready 모두 해당.
    final showBatteryHint =
        status != null &&
        status.nfcSupported &&
        status.hasCardNo &&
        !status.batteryUnrestricted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: GestureDetector(
            onTap: tappable ? _retryService : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 작동 중일 때 펄스 dot
                  if (status?.ui == S1PassUiState.ready)
                    _PulseDot(color: color)
                  else
                    Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.labelMd.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tappable) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Symbols.touch_app,
                      size: 14,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showBatteryHint) ...[
          const SizedBox(height: 8),
          _BatteryHintBanner(onTap: _requestBatteryUnrestricted),
        ],
      ],
    );
  }

  (String, IconData, Color) _resolve(S1PassUiState? ui) {
    switch (ui) {
      case S1PassUiState.ready:
        return (
          'NFC 출입 가능 · 폰을 게이트에 대세요',
          Symbols.contactless,
          Colors.green.shade700,
        );
      case S1PassUiState.notRunning:
        return (
          'NFC 준비 중… (탭하여 활성화)',
          Symbols.hourglass_empty,
          AppColors.onSurfaceVariant,
        );
      case S1PassUiState.nfcOff:
        return ('NFC 꺼짐 — 설정에서 켜주세요', Symbols.nfc, Colors.orange.shade700);
      case S1PassUiState.noNfc:
        return (
          '이 기기는 NFC 미지원',
          Symbols.do_not_disturb,
          AppColors.onSurfaceVariant,
        );
      case S1PassUiState.noCard:
        return ('로그인하면 자동 활성화', Symbols.lock, AppColors.onSurfaceVariant);
      case null:
        return ('NFC 상태 확인 중…', Symbols.refresh, AppColors.onSurfaceVariant);
    }
  }
}

/// NFC 출입은 ForegroundService가 백그라운드에서 살아있어야 동작한다. 배터리 최적화
/// '제한 없음'이 안 돼있으면 OS가 절전 종료할 수 있어, 앱을 닫으면 태깅이 끊긴다는
/// 점을 사용자에게 명시적으로 고지하고 한 번에 설정으로 보낸다. NFC chip 바로 아래에
/// 노출 — chip은 "지금 켜져있음"을, 이 배너는 "닫아도 유지되려면 이게 필요"를 말한다.
class _BatteryHintBanner extends StatelessWidget {
  const _BatteryHintBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Colors.orange.shade800;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Symbols.battery_alert, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '배터리 사용량을 '),
                    TextSpan(
                      text: "'제한 없음'",
                      style: AppTypography.labelSm.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(
                      text: '으로 설정해야 앱을 닫아도 NFC 출입이 동작합니다. 탭하여 설정하기 →',
                    ),
                  ],
                ),
                style: AppTypography.labelSm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final alpha = 0.5 + 0.5 * _ctrl.value;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: alpha),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * alpha),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
