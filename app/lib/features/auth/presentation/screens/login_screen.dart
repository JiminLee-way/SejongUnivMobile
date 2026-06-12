import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_exception.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/official_brand_logo.dart';

/// 로그인 진입 화면.
///
/// 풀스크린 캠퍼스 항공 사진 + 브랜드 빨간 오버레이 + 우측 큰 반투명 로고로
/// 첫 인상을 강하게. 폼은 하단 흰색 글래스 카드로 띄워서 시안 분리. 진입 시
/// 배경에 슬로우 켄번스 줌(20s loop) — 정적인 사진을 살아있게 보이게 한다.
///
/// 성공 시 화면 자체에서 라우팅하지 않는다 — `authStateProvider`가 갱신되면
/// [AuthGate]의 reveal transition이 자동으로 [AppShell]로 교체.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _autoLogin = true;
  bool _termsAgreed = false;
  bool _pwVisible = false;
  bool _isSigningIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prefillLastUserId();
  }

  Future<void> _prefillLastUserId() async {
    final storage = ref.read(tokenStorageProvider);
    final last = await storage.readLastUserId();
    if (mounted && last != null && last.isNotEmpty && _idCtrl.text.isEmpty) {
      _idCtrl.text = last;
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _termsAgreed &&
      !_isSigningIn &&
      _idCtrl.text.trim().isNotEmpty &&
      _pwCtrl.text.isNotEmpty;

  Future<void> _onLoginPressed() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .login(
            username: _idCtrl.text.trim(),
            password: _pwCtrl.text,
            rememberMe: _autoLogin,
          );
      // 성공: setState 안 함. AuthGate가 화면 교체 (signature reveal transition).
    } on SejongApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _errorMessage = '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final mediaPaddingBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      // primary 빨강 — 이미지 로딩 전 한 프레임에도 빨간 화면이 보이도록.
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─ 캠퍼스 항공 사진 (정적)
          const _CampusBackdrop(),
          // ─ 빨간 그라데이션 오버레이 + 비네트
          const _BrandOverlay(),
          // ─ 우측 상단 큰 반투명 로고 (overflow OK — 살짝 잘려나가는 인상)
          const _CornerLogo(),
          // ─ 콘텐츠
          // 키보드 슬라이드 — AnimatedPadding이 viewInsets.bottom 변화를
          // easeOutCubic curve로 부드럽게 흡수. LayoutBuilder가 그 안쪽에
          // 있으므로 키보드만큼 줄어든 영역에서 minHeight를 계산 → 폼 카드가
          // 키보드 위까지 자연스럽게 떠오른다. duration은 Android IME
          // 기본 곡선(약 300ms)과 거의 일치하도록 280ms.
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: AppSpacing.marginMobile,
                      right: AppSpacing.marginMobile,
                      top: AppSpacing.stackMd,
                      bottom: AppSpacing.stackMd + mediaPaddingBottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - AppSpacing.stackMd * 2,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.stackLg),
                            const _BrandText(),
                            const Spacer(),
                            _FormCard(
                              idCtrl: _idCtrl,
                              pwCtrl: _pwCtrl,
                              pwVisible: _pwVisible,
                              onTogglePwVisible: () =>
                                  setState(() => _pwVisible = !_pwVisible),
                              autoLogin: _autoLogin,
                              onAutoLoginChanged: (v) =>
                                  setState(() => _autoLogin = v),
                              termsAgreed: _termsAgreed,
                              onTermsChanged: (v) =>
                                  setState(() => _termsAgreed = v),
                              onViewTerms: () => Navigator.of(
                                context,
                              ).push(slideRoute(const PrivacyPolicyScreen())),
                              onFieldChanged: () => setState(() {}),
                              errorMessage: _errorMessage,
                              isLoading: _isSigningIn,
                              onLogin: _canSubmit ? _onLoginPressed : null,
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            const _OperationNotice(),
                            const SizedBox(height: AppSpacing.stackSm),
                            const _FooterNote(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Campus Backdrop ────────────────────────────────────────────────────────

class _CampusBackdrop extends StatelessWidget {
  const _CampusBackdrop();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/login_campus_bg.jpg',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      // 이미지 로드 전 한 프레임 처리 — 빨간 배경(Scaffold) 그대로 보임.
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.primary),
    );
  }
}

// ─── Brand Overlay ──────────────────────────────────────────────────────────

class _BrandOverlay extends StatelessWidget {
  const _BrandOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // 베이스 빨간 톤. private asset overlay가 제공하는 실제 캠퍼스 사진이
          // 묻히지 않도록 진한 브랜드 tint만 얹는다.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.62),
              ),
            ),
          ),
          // 상단→하단 그라데이션 — 상단을 더 짙게(로고 영역) 하단을 살짝 옅게(폼 카드 가독성).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.28),
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.46),
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // 비네트 — 모서리 살짝 어둡게. depth.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
                  ],
                  stops: const [0.65, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corner Logo ────────────────────────────────────────────────────────────

class _CornerLogo extends StatelessWidget {
  const _CornerLogo();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 화면 width의 95%, 우측으로 일부 잘려나가게 — image #17처럼 큼지막한 마크.
    final logoSize = (size.width * 0.95).clamp(280.0, 460.0);
    return Positioned(
      top: -logoSize * 0.12,
      right: -logoSize * 0.18,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.22,
          child: OfficialBrandLogo(
            width: logoSize,
            height: logoSize,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

// ─── Brand Text (큰 타이틀) ─────────────────────────────────────────────────

class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OfficialSeal(),
          const SizedBox(height: 18),
          Text(
            'Sejong Univ',
            style: AppTypography.headlineLg.copyWith(
              fontSize: 44,
              height: 1.05,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Text(
            'Station',
            style: AppTypography.headlineLg.copyWith(
              fontSize: 44,
              height: 1.05,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.32),
                width: 1,
              ),
            ),
            child: Text(
              '세종대역 · 세종대 모바일 학생 서비스',
              style: AppTypography.labelMd.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialSeal extends StatelessWidget {
  const _OfficialSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: OfficialBrandLogo(
        fit: BoxFit.contain,
        fallbackColor: AppColors.primary,
        fallbackColorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}

// ─── Form Card ──────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.idCtrl,
    required this.pwCtrl,
    required this.pwVisible,
    required this.onTogglePwVisible,
    required this.autoLogin,
    required this.onAutoLoginChanged,
    required this.termsAgreed,
    required this.onTermsChanged,
    required this.onViewTerms,
    required this.onFieldChanged,
    required this.errorMessage,
    required this.isLoading,
    required this.onLogin,
  });

  final TextEditingController idCtrl;
  final TextEditingController pwCtrl;
  final bool pwVisible;
  final VoidCallback onTogglePwVisible;
  final bool autoLogin;
  final ValueChanged<bool> onAutoLoginChanged;
  final bool termsAgreed;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onViewTerms;
  final VoidCallback onFieldChanged;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LoginField(
            controller: idCtrl,
            hint: '학번',
            icon: Symbols.person,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.number,
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 10),
          _LoginField(
            controller: pwCtrl,
            hint: '비밀번호',
            icon: Symbols.lock,
            obscure: !pwVisible,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onFieldChanged(),
            onSubmitted: (_) => onLogin?.call(),
            suffix: IconButton(
              onPressed: onTogglePwVisible,
              splashRadius: 18,
              icon: Icon(
                pwVisible ? Symbols.visibility : Symbols.visibility_off,
                size: 20,
                fill: pwVisible ? 1 : 0,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: errorMessage!),
          ],
          const SizedBox(height: 8),
          _SejongCheckRow(
            value: autoLogin,
            onChanged: onAutoLoginChanged,
            label: '자동 로그인',
          ),
          _SejongCheckRow(
            value: termsAgreed,
            onChanged: onTermsChanged,
            label: '서비스 약관에 동의합니다',
            required: true,
            trailing: TextButton(
              onPressed: onViewTerms,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '보기',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LoginButton(onTap: onLogin, isLoading: isLoading),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.32),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.error,
            fill: 1,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Text Field ─────────────────────────────────────────────────────────────

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceContainerLow.withValues(alpha: 0.85),
        hintText: hint,
        hintStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: border(AppColors.outline.withValues(alpha: 0.18), 1.0),
        enabledBorder: border(AppColors.outline.withValues(alpha: 0.18), 1.0),
        focusedBorder: border(AppColors.primary, 1.6),
      ),
    );
  }
}

// ─── Custom Checkbox ────────────────────────────────────────────────────────

class _SejongCheckRow extends StatelessWidget {
  const _SejongCheckRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.required = false,
    this.trailing,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _CheckBox(value: value),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    if (required)
                      const TextSpan(
                        text: ' (필수)',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: value
              ? AppColors.primary
              : AppColors.outline.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: value
          ? const Icon(
              Symbols.check,
              size: 14,
              color: AppColors.onPrimary,
              fill: 1,
              weight: 700,
            )
          : null,
    );
  }
}

// ─── Login Button ───────────────────────────────────────────────────────────

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onTap, required this.isLoading});
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 54,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.login,
                      fill: 1,
                      size: 18,
                      color: enabled
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '로그인',
                      style: AppTypography.labelMd.copyWith(
                        color: enabled
                            ? AppColors.onPrimary
                            : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Operation Notice (창의학기제 임시 운영 안내) ──────────────────────────
//
// 본 앱은 학교에서 배포한 앱이 아니라 학생 개인이 창의학기제 과정에서 만든 한시적
// 운영물이라는 점을 사용자가 로그인 단계에서 미리 인지하도록 표시한다.
// 빨간 brand overlay 위에 흰 반투명 카드로 띄워 시인성 + 시각적 조화 둘 다 잡음.

class _OperationNotice extends StatelessWidget {
  const _OperationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.info,
            size: 16,
            fill: 1,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '세종대역은 2026-1학기 창의학기제 성과물로 2026년까지 임시 운영됩니다.',
              style: AppTypography.labelSm.copyWith(
                color: Colors.white,
                height: 1.45,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer ─────────────────────────────────────────────────────────────────

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '© Sejong University',
        style: AppTypography.labelSm.copyWith(
          color: Colors.white.withValues(alpha: 0.78),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
