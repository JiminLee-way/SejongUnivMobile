import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/notices/data/datasources/notice_attachment_downloader.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/providers/notice_providers.dart';
import 'package:sejong_smart_campus/features/notices/presentation/widgets/notice_html_view.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 공지/뉴스 통합 상세 화면.
///
/// 같은 schema (`SejongNoticeDetail`)를 쓰지만 endpoint base가
/// notice(`university-notice`)와 news(`sejong-news`)로 다르기 때문에
/// [NoticeDetailArg]가 union 역할을 한다.
class NoticeDetailScreen extends ConsumerWidget {
  const NoticeDetailScreen({super.key, required NoticeDetailArg this.arg})
    : injected = null,
      injectedTitle = null;

  /// 정적 detail 주입 모드 — 네트워크 fetch 없이 이미 가진 [SejongNoticeDetail]을
  /// 그대로 렌더. 홈 Hero 이벤트 카드(서버 `home_events`)가 같은 뷰어 UI를
  /// 재활용하기 위한 진입점. [arg] 기반 fetch/새로고침 경로를 타지 않는다.
  const NoticeDetailScreen.staticDetail({
    super.key,
    required SejongNoticeDetail detail,
    required String title,
  }) : injected = detail,
       injectedTitle = title,
       arg = null;

  final NoticeDetailArg? arg;
  final SejongNoticeDetail? injected;
  final String? injectedTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final injected = this.injected;
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: injected != null
                  ? _DetailBody(detail: injected)
                  : SejongRefresh(
                      onRefresh: () async {
                        ref.invalidate(noticeDetailProvider(arg!));
                        await Future<void>.delayed(
                          const Duration(milliseconds: 400),
                        );
                      },
                      topInset: mq.padding.top + 64,
                      child: ref
                          .watch(noticeDetailProvider(arg!))
                          .when(
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
                            error: (e, _) => _ErrorView(error: e),
                            data: (detail) => _DetailBody(detail: detail),
                          ),
                    ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(
                title: injected != null ? injectedTitle! : arg!.categoryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});
  final SejongNoticeDetail detail;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        mq.padding.top + 64 + 8,
        AppSpacing.marginMobile,
        120 + mq.padding.bottom,
      ),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _HeaderCard(detail: detail),
        const SizedBox(height: 12),
        if (detail.imageUrl != null && detail.imageUrl!.isNotEmpty) ...[
          _CoverImage(url: detail.imageUrl!),
          const SizedBox(height: 12),
        ],
        GlassCard(
          borderRadius: AppRadius.lg,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: NoticeHtmlView(html: detail.content),
        ),
        if (detail.attachments.isNotEmpty) ...[
          const SizedBox(height: 14),
          _AttachmentsSection(attachments: detail.attachments),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});
  final SejongNoticeDetail detail;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (detail.categoryName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    detail.categoryName,
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (detail.attachments.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.attach_file,
                        size: 13,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${detail.attachments.length}',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 11,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            detail.title,
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if ((detail.writerName ?? '').isNotEmpty) ...[
                Icon(
                  Symbols.account_circle,
                  size: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  detail.writerName!,
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (detail.writtenAt != null) ...[
                Icon(
                  Symbols.schedule,
                  size: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  _fmtDate(detail.writtenAt!),
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              if (detail.viewCount > 0) ...[
                Icon(
                  Symbols.visibility,
                  size: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  '${detail.viewCount}',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.surfaceContainerHigh,
            alignment: Alignment.center,
            child: const Icon(
              Symbols.image_not_supported,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── attachments ───────────────────────────

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.attachments});
  final List<NoticeAttachment> attachments;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.attach_file,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '첨부파일 ${attachments.length}',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < attachments.length; i++) ...[
            _AttachmentRow(attachment: attachments[i]),
            if (i != attachments.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  height: 1,
                  color: AppColors.onSurface.withValues(alpha: 0.06),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatefulWidget {
  const _AttachmentRow({required this.attachment});
  final NoticeAttachment attachment;
  @override
  State<_AttachmentRow> createState() => _AttachmentRowState();
}

class _AttachmentRowState extends State<_AttachmentRow> {
  final _downloader = NoticeAttachmentDownloader();
  double? _progress;
  bool _busy = false;

  Future<void> _download({required bool open}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final r = await (open
        ? _downloader.downloadAndOpen(
            widget.attachment,
            onProgress: (rec, total) {
              if (!mounted) return;
              setState(() {
                _progress = total > 0 ? rec / total : null;
              });
            },
          )
        : _downloader.download(
            widget.attachment,
            onProgress: (rec, total) {
              if (!mounted) return;
              setState(() {
                _progress = total > 0 ? rec / total : null;
              });
            },
          ));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (r.success) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            open
                ? '${widget.attachment.fileName} 열기'
                : '${widget.attachment.fileName} 저장됨',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(r.message ?? '실패했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _iconBg(a.extension),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              _iconFor(a.extension),
              size: 18,
              color: _iconFg(a.extension),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (a.prettySize.isNotEmpty || a.extension.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (a.extension.isNotEmpty) a.extension.toUpperCase(),
                      if (a.prettySize.isNotEmpty) a.prettySize,
                    ].join(' · '),
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _progress,
                    minHeight: 3,
                    backgroundColor: AppColors.onSurface.withValues(
                      alpha: 0.06,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '저장',
            icon: const Icon(
              Symbols.download,
              color: AppColors.onSurfaceVariant,
            ),
            onPressed: _busy ? null : () => _download(open: false),
            splashRadius: 20,
          ),
          IconButton(
            tooltip: '열기',
            icon: const Icon(Symbols.open_in_new, color: AppColors.primary),
            onPressed: _busy ? null : () => _download(open: true),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String ext) {
    return switch (ext) {
      'pdf' => Symbols.picture_as_pdf,
      'hwp' || 'hwpx' || 'doc' || 'docx' => Symbols.description,
      'xls' || 'xlsx' || 'csv' => Symbols.table_view,
      'ppt' || 'pptx' => Symbols.slideshow,
      'zip' || 'rar' || '7z' => Symbols.folder_zip,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => Symbols.image,
      _ => Symbols.draft,
    };
  }

  Color _iconBg(String ext) {
    return switch (ext) {
      'pdf' => const Color(0xFFFFE6E6),
      'hwp' || 'hwpx' || 'doc' || 'docx' => const Color(0xFFE6F0FF),
      'xls' || 'xlsx' || 'csv' => const Color(0xFFE6F7EE),
      'ppt' || 'pptx' => const Color(0xFFFFF1E0),
      'zip' || 'rar' || '7z' => const Color(0xFFF0EAFF),
      _ => AppColors.outline.withValues(alpha: 0.10),
    };
  }

  Color _iconFg(String ext) {
    return switch (ext) {
      'pdf' => const Color(0xFFD03B3B),
      'hwp' || 'hwpx' || 'doc' || 'docx' => const Color(0xFF2563EB),
      'xls' || 'xlsx' || 'csv' => const Color(0xFF059669),
      'ppt' || 'pptx' => const Color(0xFFEA580C),
      'zip' || 'rar' || '7z' => const Color(0xFF7C3AED),
      _ => AppColors.onSurfaceVariant,
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.error,
              fill: 1,
              size: 36,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              '본문을 불러오지 못했어요',
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
