import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/ucheck_providers.dart';

/// UCheck 자격증명 fallback 모달.
///
/// **일반 사용자 흐름에서는 안 보임** — sjapp 로그인 직후 동일 ID/PW로 UCheck도
/// 자동 인증된다 ([bootstrapUCheckWithSjappCredentials]).
///
/// 이 화면이 노출되는 케이스:
/// 1. UCheck 서버가 첫 로그인 시점에 잠시 죽어있어서 자동 발급 실패
/// 2. 사용자가 UCheck 비밀번호만 학교 홈페이지에서 따로 변경한 경우 (드묾)
/// 3. secure storage가 OS에 의해 초기화 (앱 데이터 삭제)
///
/// 학번은 sjapp `currentUserProvider`에서 자동 채움. 비밀번호만 입력.
class UCheckLoginScreen extends ConsumerStatefulWidget {
  const UCheckLoginScreen({super.key});

  @override
  ConsumerState<UCheckLoginScreen> createState() => _UCheckLoginScreenState();
}

class _UCheckLoginScreenState extends ConsumerState<UCheckLoginScreen> {
  late final TextEditingController _passwordController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = '먼저 sjapp에 로그인해주세요.');
      return;
    }
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      setState(() => _error = '비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final repo = ref.read(ucheckRepositoryProvider);
    final ok = await repo.loginWithCredentials(
      username: user.userId,
      password: pwd,
    );

    if (!mounted) return;
    if (ok) {
      ref.invalidate(ucheckDataProvider);
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = '로그인 실패 — 학번 또는 비밀번호를 확인해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // drag handle
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Symbols.lock_open, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('UCheck 자격증명', style: AppTypography.headlineMd),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'sjapp과 동일한 비밀번호를 입력해주세요. 한 번만 입력하면 다음부터는 자동 로그인됩니다.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: TextEditingController(text: user?.userId ?? ''),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '학번',
                  prefixIcon: Icon(Symbols.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: Icon(Symbols.password),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Symbols.error, size: 18, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTypography.bodyMd.copyWith(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                    : const Text('로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 외부에서 호출 헬퍼 — `showModalBottomSheet`로 띄움.
Future<bool?> showUCheckLoginSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false, // 사용자 실수로 닫지 않게
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const UCheckLoginScreen(),
  );
}
