import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/mcp/presentation/providers/mcp_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';

/// MCP/AI 어시스턴트 채팅 화면.
///
/// sjapp 백엔드의 `/api/v1/mcp/*` 활용. 응답 스키마는 best-effort 매핑이라
/// 잘못된 키가 오면 "응답을 받지 못했어요" 표시. session id 관리는 추후.
class McpChatScreen extends ConsumerStatefulWidget {
  const McpChatScreen({super.key});
  @override
  ConsumerState<McpChatScreen> createState() => _McpChatScreenState();
}

class _McpChatScreenState extends ConsumerState<McpChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final body = (text ?? _inputCtrl.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _messages.add(_Message(role: _Role.user, text: body));
      _sending = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();
    final remote = await ref.read(mcpRemoteProvider.future);
    final reply = await remote.sendChat(body);
    if (!mounted) return;
    setState(() {
      _messages.add(
        _Message(
          role: _Role.assistant,
          text: reply ?? '죄송해요, 지금은 답변을 받지 못했어요.',
        ),
      );
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final greetingAsync = ref.watch(mcpGreetingProvider);
    final questionsAsync = ref.watch(mcpRecommendedQuestionsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Column(
          children: [
            SizedBox(height: mq.padding.top + 64),
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile,
                  16,
                  AppSpacing.marginMobile,
                  16,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  if (_messages.isEmpty)
                    _IntroCard(
                      greeting:
                          greetingAsync.value ??
                          '안녕하세요! 세종 학사·시설·일정 등 무엇이든 물어보세요.',
                      questions:
                          questionsAsync.value ??
                          const [
                            '오늘 학식 메뉴 알려줘',
                            '내 이번주 시간표 정리해줘',
                            '도서관 운영시간 알려줘',
                          ],
                      onPick: _send,
                    ),
                  for (final m in _messages) _Bubble(message: m),
                  if (_sending)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _Composer(
              controller: _inputCtrl,
              sending: _sending,
              onSend: () => _send(),
              bottomPad: mq.padding.bottom,
            ),
          ],
        ),
      ),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(mq.padding.top + 64),
        child: const _AppBar(),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar();
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
          const Icon(
            Symbols.auto_awesome,
            size: 20,
            fill: 1,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '세종 AI 어시스턴트',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Role { user, assistant }

class _Message {
  const _Message({required this.role, required this.text});
  final _Role role;
  final String text;
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.greeting,
    required this.questions,
    required this.onPick,
  });
  final String greeting;
  final List<String> questions;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.auto_awesome,
                size: 22,
                fill: 1,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '세종 AI 어시스턴트',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            greeting,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurface,
              height: 1.5,
            ),
          ),
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '추천 질문',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in questions)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      onTap: () => onPick(q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          q,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _Message message;
  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const Icon(
              Symbols.auto_awesome,
              size: 16,
              fill: 1,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(
                    isUser ? AppRadius.lg : AppRadius.sm,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? AppRadius.sm : AppRadius.lg,
                  ),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: AppColors.outline.withValues(alpha: 0.2),
                      ),
              ),
              child: Text(
                message.text,
                style: AppTypography.bodyMd.copyWith(
                  color: isUser ? AppColors.onPrimary : AppColors.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.bottomPad,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final double bottomPad;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        10,
        AppSpacing.marginMobile,
        10 + bottomPad,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppTypography.bodyMd,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: '무엇이든 물어보세요',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: sending ? null : onSend,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Symbols.send, color: AppColors.onPrimary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
