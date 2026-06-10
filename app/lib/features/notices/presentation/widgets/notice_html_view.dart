import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

/// sjapp 공지/뉴스 본문 HTML 렌더러.
///
/// Froala가 출력하는 한정된 마크업만 처리:
/// - 블록: `<p>`, `<div>`, `<br>`, `<ul>`/`<ol>`, `<li>`, `<img>`
/// - 인라인: `<span style=...>`, `<a href>`, `<strong>`/`<b>`, `<em>`/`<i>`,
///   텍스트 노드
///
/// 인라인 style 파싱: `font-size`(px), `color`(rgb/hex), `font-weight`,
/// `text-decoration: underline`. 그 외는 무시.
///
/// 이미지 src가 절대 URL이면 그대로, 상대 경로면 base URL을 보정한다.
///
/// **왜 flutter_html이 아니라 custom인가**: 본문 HTML이 단순한 편이라
/// ~200줄 mini-parser로 충분하고, 무거운 deps + Flutter 새 버전 호환 risk를
/// 회피하기 위함.
class NoticeHtmlView extends StatelessWidget {
  const NoticeHtmlView({
    super.key,
    required this.html,
    this.imageBaseUrl = ServiceUrls.sejongWeb,
    this.baseFontSize = 15,
  });

  final String html;
  final String imageBaseUrl;
  final double baseFontSize;

  @override
  Widget build(BuildContext context) {
    final doc = parse(html);
    final body = doc.body ?? doc.documentElement;
    if (body == null) return const SizedBox.shrink();
    // `<div class="fr-view">` wrapper가 있으면 그 안만 렌더 (Froala 컨벤션).
    final container = body.querySelector('.fr-view') ?? body;
    // imageOverflow: p 안에서 만난 img를 단락 widget 사이에 끼우기 위한 버킷.
    // build마다 새로 만들어야 누적 안 됨 (StatelessWidget instance 공유 케이스).
    final imageOverflow = <Widget>[];
    final children = _renderBlocks(context, container.nodes, imageOverflow);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  // ─────────────────────────── block-level ───────────────────────────

  List<Widget> _renderBlocks(
    BuildContext context,
    List<dom.Node> nodes,
    List<Widget> imageOverflow,
  ) {
    final out = <Widget>[];
    final inlineBuffer = <InlineSpan>[];

    List<Widget> drainImageOverflow() {
      if (imageOverflow.isEmpty) return const [];
      final copy = List<Widget>.from(imageOverflow);
      imageOverflow.clear();
      return copy;
    }

    void flushInline() {
      if (inlineBuffer.isEmpty) return;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableText.rich(
            TextSpan(
              style: _baseStyle(),
              children: List<InlineSpan>.from(inlineBuffer),
            ),
          ),
        ),
      );
      inlineBuffer.clear();
    }

    for (final node in nodes) {
      if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        switch (tag) {
          case 'p':
          case 'div':
            flushInline();
            final paragraphSpans = _renderInline(
              context,
              node.nodes,
              parentStyle: _baseStyle(),
              imageOverflow: imageOverflow,
            );
            // p 안에 img만 있는 경우엔 paragraphSpans가 비고 widget만 분리되어
            // imageOverflow에 push되므로 paragraphSpans는 비울 수 있음.
            if (paragraphSpans.isNotEmpty) {
              out.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText.rich(
                    TextSpan(style: _baseStyle(), children: paragraphSpans),
                  ),
                ),
              );
            }
            for (final w in drainImageOverflow()) {
              out.add(w);
            }
            break;
          case 'br':
            inlineBuffer.add(const TextSpan(text: '\n'));
            break;
          case 'img':
            flushInline();
            final w = _buildImage(context, node);
            if (w != null) out.add(w);
            break;
          case 'ul':
          case 'ol':
            flushInline();
            out.add(
              _buildList(
                context,
                node,
                ordered: tag == 'ol',
                imageOverflow: imageOverflow,
              ),
            );
            break;
          case 'hr':
            flushInline();
            out.add(
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0x14000000)),
              ),
            );
            break;
          case 'h1':
          case 'h2':
          case 'h3':
          case 'h4':
            flushInline();
            out.add(
              _buildHeading(context, node, tag, imageOverflow: imageOverflow),
            );
            break;
          case 'table':
            flushInline();
            out.add(_buildTable(context, node, imageOverflow: imageOverflow));
            break;
          default:
            // unknown block: walk children as inline
            inlineBuffer.addAll(
              _renderInline(
                context,
                node.nodes,
                parentStyle: _baseStyle(),
                imageOverflow: imageOverflow,
              ),
            );
        }
      } else if (node is dom.Text) {
        final text = node.text.replaceAll(' ', ' ');
        if (text.trim().isEmpty) continue;
        inlineBuffer.add(TextSpan(text: text));
      }
    }

    flushInline();
    for (final w in drainImageOverflow()) {
      out.add(w);
    }
    return out;
  }

  // ─────────────────────────── inline ───────────────────────────

  List<InlineSpan> _renderInline(
    BuildContext context,
    List<dom.Node> nodes, {
    required TextStyle parentStyle,
    required List<Widget> imageOverflow,
  }) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final txt = node.text.replaceAll(' ', ' ');
        if (txt.isEmpty) continue;
        spans.add(TextSpan(text: txt, style: parentStyle));
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        switch (tag) {
          case 'br':
            spans.add(const TextSpan(text: '\n'));
            break;
          case 'img':
            // 인라인 img는 어차피 큰 이미지가 대부분이므로 별도 widget으로.
            final w = _buildImage(context, node);
            if (w != null) imageOverflow.add(w);
            break;
          case 'span':
          case 'font':
          case 'a':
            final childStyle = _mergeStyle(
              parentStyle,
              _parseInlineStyle(node, tag: tag),
            );
            spans.addAll(
              _renderInline(
                context,
                node.nodes,
                parentStyle: childStyle,
                imageOverflow: imageOverflow,
              ),
            );
            break;
          case 'strong':
          case 'b':
            spans.addAll(
              _renderInline(
                context,
                node.nodes,
                parentStyle: parentStyle.copyWith(fontWeight: FontWeight.w700),
                imageOverflow: imageOverflow,
              ),
            );
            break;
          case 'em':
          case 'i':
            spans.addAll(
              _renderInline(
                context,
                node.nodes,
                parentStyle: parentStyle.copyWith(fontStyle: FontStyle.italic),
                imageOverflow: imageOverflow,
              ),
            );
            break;
          case 'u':
            spans.addAll(
              _renderInline(
                context,
                node.nodes,
                parentStyle: parentStyle.copyWith(
                  decoration: TextDecoration.underline,
                ),
                imageOverflow: imageOverflow,
              ),
            );
            break;
          default:
            spans.addAll(
              _renderInline(
                context,
                node.nodes,
                parentStyle: parentStyle,
                imageOverflow: imageOverflow,
              ),
            );
        }
      }
    }
    return spans;
  }

  // ─────────────────────────── pieces ───────────────────────────

  Widget? _buildImage(BuildContext context, dom.Element node) {
    final rawSrc = (node.attributes['src'] ?? '').trim();
    if (rawSrc.isEmpty || rawSrc.startsWith('data:')) return null;
    final src = _resolveSrc(rawSrc);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openImageViewer(context, src),
            child: Image.network(
              src,
              fit: BoxFit.fitWidth,
              width: double.infinity,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                color: AppColors.surfaceContainerHigh,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Symbols.image_not_supported,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '이미지를 불러오지 못했어요',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 160,
                  alignment: Alignment.center,
                  color: AppColors.surfaceContainerHigh,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    dom.Element node, {
    required bool ordered,
    required List<Widget> imageOverflow,
  }) {
    final items = node.children
        .where((c) => (c.localName?.toLowerCase() ?? '') == 'li')
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      ordered ? '${i + 1}.' : '·',
                      style: _baseStyle().copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText.rich(
                      TextSpan(
                        style: _baseStyle(),
                        children: _renderInline(
                          context,
                          items[i].nodes,
                          parentStyle: _baseStyle(),
                          imageOverflow: imageOverflow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeading(
    BuildContext context,
    dom.Element node,
    String tag, {
    required List<Widget> imageOverflow,
  }) {
    final size = switch (tag) {
      'h1' => baseFontSize + 8,
      'h2' => baseFontSize + 6,
      'h3' => baseFontSize + 4,
      _ => baseFontSize + 2,
    };
    final style = _baseStyle().copyWith(
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: 1.3,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: SelectableText.rich(
        TextSpan(
          style: style,
          children: _renderInline(
            context,
            node.nodes,
            parentStyle: style,
            imageOverflow: imageOverflow,
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    dom.Element node, {
    required List<Widget> imageOverflow,
  }) {
    // 간단 fallback — 표는 행/셀을 Row/Column으로. 복잡 표는 깨질 수 있으니
    // 호출자가 "원본 보기" 옵션을 제공하길 권장. 본문에 표는 거의 없음.
    final rows = node.querySelectorAll('tr');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in r.children.where(
                    (e) => ['td', 'th'].contains(e.localName?.toLowerCase()),
                  ))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SelectableText.rich(
                          TextSpan(
                            style: _baseStyle(),
                            children: _renderInline(
                              context,
                              c.nodes,
                              parentStyle: _baseStyle(),
                              imageOverflow: imageOverflow,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────── style helpers ───────────────────────────

  TextStyle _baseStyle() => AppTypography.labelMd.copyWith(
    fontSize: baseFontSize,
    height: 1.55,
    color: AppColors.onSurface,
    fontWeight: FontWeight.w500,
  );

  /// Froala inline style를 TextStyle override로 변환.
  TextStyle _parseInlineStyle(dom.Element node, {required String tag}) {
    final base = const TextStyle();
    final raw = node.attributes['style'];
    var style = base;
    if (raw != null && raw.isNotEmpty) {
      for (final part in raw.split(';')) {
        final kv = part.split(':');
        if (kv.length != 2) continue;
        final k = kv[0].trim().toLowerCase();
        final v = kv[1].trim();
        switch (k) {
          case 'font-size':
            final px = _parsePx(v);
            // 본문 가독성 위해 18px → baseFontSize 정도로 약간 축소.
            // 너무 작은 값(<11)은 무시.
            if (px != null && px >= 11) {
              style = style.copyWith(
                fontSize: (px * 0.92).clamp(baseFontSize - 1, baseFontSize + 8),
              );
            }
            break;
          case 'color':
            final c = _parseColor(v);
            if (c != null) style = style.copyWith(color: c);
            break;
          case 'font-weight':
            final fw = _parseWeight(v);
            if (fw != null) style = style.copyWith(fontWeight: fw);
            break;
          case 'text-decoration':
            if (v.contains('underline')) {
              style = style.copyWith(decoration: TextDecoration.underline);
            }
            break;
          case 'background-color':
            final c = _parseColor(v);
            if (c != null) style = style.copyWith(backgroundColor: c);
            break;
        }
      }
    }
    if (tag == 'a') {
      style = style.copyWith(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
      );
    }
    return style;
  }

  TextStyle _mergeStyle(TextStyle parent, TextStyle child) {
    return parent.merge(child);
  }

  double? _parsePx(String v) {
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*px').firstMatch(v);
    if (m == null) {
      // 단위 없는 숫자도 px로.
      final n = double.tryParse(v.trim());
      return n;
    }
    return double.tryParse(m.group(1)!);
  }

  Color? _parseColor(String v) {
    final s = v.trim().toLowerCase();
    // rgb(0, 0, 0) / rgba(...)
    final rgb = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s);
    if (rgb != null) {
      final parts = rgb.group(1)!.split(',').map((e) => e.trim()).toList();
      if (parts.length >= 3) {
        final r = int.tryParse(parts[0]);
        final g = int.tryParse(parts[1]);
        final b = int.tryParse(parts[2]);
        if (r != null && g != null && b != null) {
          return Color.fromARGB(255, r, g, b);
        }
      }
    }
    // #rrggbb / #rgb
    if (s.startsWith('#')) {
      var hex = s.substring(1);
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      if (hex.length == 6) {
        final n = int.tryParse(hex, radix: 16);
        if (n != null) return Color(0xFF000000 | n);
      }
    }
    return null;
  }

  FontWeight? _parseWeight(String v) {
    final s = v.trim().toLowerCase();
    return switch (s) {
      'bold' => FontWeight.w700,
      'bolder' => FontWeight.w800,
      'normal' => FontWeight.w400,
      _ => switch (int.tryParse(s)) {
        100 => FontWeight.w100,
        200 => FontWeight.w200,
        300 => FontWeight.w300,
        400 => FontWeight.w400,
        500 => FontWeight.w500,
        600 => FontWeight.w600,
        700 => FontWeight.w700,
        800 => FontWeight.w800,
        900 => FontWeight.w900,
        _ => null,
      },
    };
  }

  String _resolveSrc(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) return src;
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('/')) return '$imageBaseUrl$src';
    return '$imageBaseUrl/$src';
  }

  void _openImageViewer(BuildContext context, String src) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => _ImageViewer(src: src),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.src});
  final String src;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Center(
              child: Image.network(
                src,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Symbols.broken_image,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Symbols.close, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
