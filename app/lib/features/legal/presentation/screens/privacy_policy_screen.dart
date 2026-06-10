import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

/// 개인정보 처리방침 표시 화면.
///
/// 본문은 [assets/legal/privacy_policy.md] 한 파일에서 읽고 자체 단순 markdown
/// 렌더로 표시한다. flutter_markdown 의존성 추가 대신 — 우리 본문은 사용하는
/// 문법이 좁음(#/##/###, **bold**, "- " bullet, "|" 표) — 한 파일 안에서 처리.
///
/// 표는 모바일에서 가로로 깨지지 않도록 행 단위 카드로 풀어 렌더한다.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<String> _load() =>
      rootBundle.loadString('assets/legal/privacy_policy.md');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_ios_new, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          '개인정보 처리방침',
          style: AppTypography.headlineMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<String>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '처리방침을 불러오지 못했어요.\n잠시 후 다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return _PolicyBody(source: snap.data!);
        },
      ),
    );
  }
}

// ─── Body ───────────────────────────────────────────────────────────────────

class _PolicyBody extends StatelessWidget {
  const _PolicyBody({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(source);
    return SelectionArea(
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: AppSpacing.marginMobile,
          right: AppSpacing.marginMobile,
          top: 8,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: blocks.length,
        itemBuilder: (context, i) => blocks[i].build(context),
      ),
    );
  }
}

// ─── Markdown 파서 ──────────────────────────────────────────────────────────
//
// 본문이 단순한 문법만 사용하므로 line-by-line state machine로 충분.
// 헤더(`#`,`##`,`###`), bullet(`- `), 표(`|...|`), 수평선(`---`), paragraph.
// **bold** 인라인은 paragraph/bullet 안에서 처리.

abstract class _Block {
  Widget build(BuildContext context);
}

List<_Block> _parse(String src) {
  final lines = src.split('\n');
  final blocks = <_Block>[];
  var i = 0;
  final paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(_Paragraph(paragraph.join(' ').trim()));
    paragraph.clear();
  }

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    // 빈 줄 → 문단 구분.
    if (trimmed.isEmpty) {
      flushParagraph();
      i++;
      continue;
    }

    // 수평선.
    if (trimmed == '---') {
      flushParagraph();
      blocks.add(const _Divider());
      i++;
      continue;
    }

    // 헤더 — `### `, `## `, `# `.
    final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (headerMatch != null) {
      flushParagraph();
      final level = headerMatch.group(1)!.length;
      var text = headerMatch.group(2)!.trim();
      // 우리 본문은 "## ■ ..." 형태로 ■ 기호를 헤더 안에 둠 — 그대로 표시.
      text = text.replaceAll(RegExp(r'^[■·]\s*'), '');
      blocks.add(_Header(level: level, text: text));
      i++;
      continue;
    }

    // 표 — `|`로 시작하고 다음 줄이 `|---|...` separator.
    if (trimmed.startsWith('|') && i + 1 < lines.length) {
      final next = lines[i + 1].trim();
      final isSeparator = RegExp(r'^\|[\s\-:|]+\|$').hasMatch(next);
      if (isSeparator) {
        flushParagraph();
        final headers = _splitRow(trimmed);
        final rows = <List<String>>[];
        i += 2;
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          rows.add(_splitRow(lines[i].trim()));
          i++;
        }
        blocks.add(_Table(headers: headers, rows: rows));
        continue;
      }
    }

    // bullet.
    if (trimmed.startsWith('- ')) {
      flushParagraph();
      // 같은 들여쓰기의 연속된 bullet을 한 리스트로 묶음.
      final items = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('- ')) {
        items.add(lines[i].trim().substring(2).trim());
        i++;
      }
      blocks.add(_BulletList(items: items));
      continue;
    }

    // 그 외 → paragraph 누적.
    paragraph.add(trimmed);
    i++;
  }
  flushParagraph();
  return blocks;
}

List<String> _splitRow(String line) {
  // 양 끝 `|` 제거 후 분리.
  var l = line.trim();
  if (l.startsWith('|')) l = l.substring(1);
  if (l.endsWith('|')) l = l.substring(0, l.length - 1);
  return l.split('|').map((s) => s.trim()).toList();
}

/// `**bold**` 마크다운을 Span으로 변환.
List<InlineSpan> _inlineSpans(String text, {required TextStyle base}) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*');
  var cursor = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, m.start), style: base));
    }
    spans.add(
      TextSpan(
        text: m.group(1),
        style: base.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    cursor = m.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return spans;
}

// ─── Block widgets ──────────────────────────────────────────────────────────

class _Header implements _Block {
  const _Header({required this.level, required this.text});
  final int level;
  final String text;

  @override
  Widget build(BuildContext context) {
    final TextStyle style;
    final EdgeInsets pad;
    switch (level) {
      case 1:
        style = AppTypography.headlineMd.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w800,
          height: 1.25,
        );
        pad = const EdgeInsets.only(top: 16, bottom: 12);
      case 2:
        style = AppTypography.headlineMd.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 19,
          height: 1.3,
        );
        pad = const EdgeInsets.only(top: 24, bottom: 10);
      default:
        style = AppTypography.labelMd.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        );
        pad = const EdgeInsets.only(top: 16, bottom: 8);
    }
    return Padding(
      padding: pad,
      child: Text(text, style: style),
    );
  }
}

class _Paragraph implements _Block {
  const _Paragraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.bodyMd.copyWith(
      color: AppColors.onSurface,
      height: 1.6,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(TextSpan(children: _inlineSpans(text, base: base))),
    );
  }
}

class _BulletList implements _Block {
  const _BulletList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.bodyMd.copyWith(
      color: AppColors.onSurface,
      height: 1.55,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8, left: 4),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: _inlineSpans(item, base: base)),
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

class _Divider implements _Block {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1, thickness: 0.5),
  );
}

/// 표는 모바일에서 가로 폭이 좁아 깨지므로, 행 단위 카드로 풀어서 렌더한다.
/// 각 카드 = "헤더: 값" 형태 라인 N개.
class _Table implements _Block {
  const _Table({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.labelMd.copyWith(
      color: AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = AppTypography.bodyMd.copyWith(
      color: AppColors.onSurface,
      height: 1.5,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        // 각 row Container는 width 미지정이라 child 내재폭(intrinsic)에 맞춰
        // shrink — 짧은 값이 들어간 row(예: "본인 예약 식별자...")는 폭이
        // 좁아져 긴 row와 시각 차이가 난다. stretch로 부모 가용 폭(=ListView
        // item 폭)을 강제해 모든 카드 동일 너비.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.3),
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < headers.length && c < row.length; c++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: c == headers.length - 1 ? 0 : 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(headers[c], style: labelStyle),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: _inlineSpans(row[c], base: valueStyle),
                            ),
                          ),
                        ],
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
