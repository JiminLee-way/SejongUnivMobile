import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/diagnostics/app_log.dart';
import 'package:sejong_smart_campus/core/diagnostics/crash_report.dart';
import 'package:sejong_smart_campus/core/diagnostics/diagnostics_providers.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/support/domain/entities/support_models.dart';
import 'package:sejong_smart_campus/features/support/presentation/providers/support_providers.dart';

/// 앱 1:1 문의 작성 dialog — **이 앱 자체**에 대한 문의. Supabase `app_inquiries`로
/// 전송, 학번/이름/기기 컨텍스트 자동 첨부 + (선택)최근 로그.
///
/// [attachedLog]가 주어지면(크래시 리포트 경로) 로그 첨부가 기본 ON으로 고정되고
/// 그 덤프가 첨부된다. 일반 작성 시엔 "최근 로그 첨부" 토글을 사용자가 켜면
/// [AppLog]의 최근 ~3분 버퍼가 첨부된다.
Future<void> showQnaComposeDialog(
  BuildContext context, {
  String? initialCategoryId,
  String? initialTitle,
  String? initialContent,
  String? attachedLog,
  bool isCrashReport = false,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _QnaComposeDialog(
      initialCategoryId: initialCategoryId,
      initialTitle: initialTitle,
      initialContent: initialContent,
      attachedLog: attachedLog,
      isCrashReport: isCrashReport,
    ),
  );
}

class _QnaComposeDialog extends ConsumerStatefulWidget {
  const _QnaComposeDialog({
    this.initialCategoryId,
    this.initialTitle,
    this.initialContent,
    this.attachedLog,
    this.isCrashReport = false,
  });
  final String? initialCategoryId;
  final String? initialTitle;
  final String? initialContent;
  final String? attachedLog;
  final bool isCrashReport;

  @override
  ConsumerState<_QnaComposeDialog> createState() => _QnaComposeDialogState();
}

class _QnaComposeDialogState extends ConsumerState<_QnaComposeDialog> {
  late final TextEditingController _titleCtrl = TextEditingController(
    text: widget.initialTitle,
  );
  late final TextEditingController _bodyCtrl = TextEditingController(
    text: widget.initialContent,
  );
  bool _submitting = false;
  String? _errorText;
  late String? _selectedCategoryId =
      widget.initialCategoryId ?? appInquiryCategories.first.id;

  /// 크래시 리포트면 첨부 고정(ON). 일반 작성이면 사용자 opt-in(기본 OFF).
  late bool _attachLog = widget.attachedLog != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _errorText = '제목과 본문을 모두 입력해주세요.');
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _errorText = '문의 분류를 선택해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    // 첨부 로그 결정: 크래시 덤프(고정) 우선, 아니면 토글 ON일 때 최근 버퍼.
    String? logExcerpt;
    if (_attachLog) {
      final raw = widget.attachedLog ?? AppLog.instance.dump();
      if (raw.isNotEmpty) logExcerpt = CrashReport.clamp(raw);
    }

    final user = ref.read(currentUserProvider);
    // 기기/앱 컨텍스트는 FutureProvider라 .value는 첫 로드 전 null이다(크래시
    // 프롬프트는 부팅 직후 떠서 아직 미로드). .future로 실제 로딩을 기다린다.
    DiagnosticsContext? ctx;
    try {
      ctx = await ref.read(diagnosticsContextProvider.future);
    } catch (_) {
      // 수집 실패 시 컨텍스트 없이 전송(전송 자체는 막지 않음).
    }

    try {
      await ref
          .read(appSupportRemoteProvider)
          .createInquiry(
            category: _selectedCategoryId!,
            title: title,
            content: body,
            reporterStudentId: user?.userId,
            reporterName: user?.username,
            appVersion: ctx?.appVersion,
            platform: ctx?.platform,
            osVersion: ctx?.osVersion,
            deviceModel: ctx?.deviceModel,
            logExcerpt: logExcerpt,
            isCrashReport: widget.isCrashReport,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = '문의 접수에 실패했어요. 잠시 후 다시 시도해주세요.';
      });
      return;
    }

    if (!mounted) return;
    ref.invalidate(myQnaProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('문의가 접수되었어요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isCrashReport ? Symbols.bug_report : Symbols.help,
                      size: 22,
                      color: AppColors.primary,
                      fill: 1,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isCrashReport ? '오류 리포트 보내기' : '1:1 문의 작성',
                      style: AppTypography.headlineMd.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Symbols.close,
                        color: AppColors.onSurface,
                      ),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CategoryDropdown(
                  selectedId: _selectedCategoryId,
                  enabled: !_submitting,
                  onChanged: (id) => setState(() => _selectedCategoryId = id),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  enabled: !_submitting,
                  style: AppTypography.bodyMd,
                  cursorColor: AppColors.primary,
                  decoration: _decoration('제목'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bodyCtrl,
                  enabled: !_submitting,
                  style: AppTypography.bodyMd,
                  cursorColor: AppColors.primary,
                  minLines: 4,
                  maxLines: 8,
                  decoration: _decoration('본문', alignHint: true),
                ),
                const SizedBox(height: 10),
                _LogAttachTile(
                  value: _attachLog,
                  // 크래시 리포트는 로그 첨부가 핵심이라 끄지 못하게 고정.
                  locked: widget.attachedLog != null,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _attachLog = v),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : const Text('보내기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, {bool alignHint = false}) =>
      InputDecoration(
        labelText: label,
        alignLabelWithHint: alignHint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

/// "최근 로그 첨부" 토글 + 안내. [locked]면 항상 ON 고정(크래시 리포트).
class _LogAttachTile extends StatelessWidget {
  const _LogAttachTile({
    required this.value,
    required this.locked,
    required this.onChanged,
  });
  final bool value;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.description, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '최근 로그 첨부',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  locked
                      ? '오류 진단을 위해 직전 종료 시점의 로그가 첨부됩니다.'
                      : '최근 3분간의 앱 동작 로그를 함께 보내 문제 파악을 돕습니다.',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: locked ? null : onChanged),
        ],
      ),
    );
  }
}

/// 앱 문의 분류 드롭다운 — 고정값(appInquiryCategories). sjapp 네트워크 호출 없음.
class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '문의 분류',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: AppTypography.bodyMd.copyWith(
        color: AppColors.onSurface,
        fontSize: 14,
      ),
      items: [
        for (final c in appInquiryCategories)
          DropdownMenuItem<String>(value: c.id, child: Text(c.label)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
