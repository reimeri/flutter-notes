import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Lightweight holder for a styled text segment produced during parsing.
class _Seg {
  final String text;
  final TextStyle? style;
  const _Seg(this.text, this.style);
  TextSpan toSpan() => TextSpan(text: text, style: style);
}

// ── Inline match types, ordered by priority ──────────────────────────
enum _InlineKind {
  fencedCode, // ``` … ```  (highest – no further parsing inside)
  inlineCode, // `…`
  boldItalic, // ***…*** / ___…___
  bold, //  **…** / __…__
  italic, //   *…* / _…_
  strikethrough, // ~~…~~
  image, // ![alt](url)
  link, //  [text](url)
}

class _InlineMatch {
  final int start;
  final int end;
  final _InlineKind kind;
  const _InlineMatch(this.start, this.end, this.kind);
}

class MarkdownController extends TextEditingController {
  // ── Block-level regexes (multiLine) ──────────────────────────────────
  // Ordered from most specific (######) to least specific (#) so the first
  // matching rule wins during the single-regex scan.
  static final RegExp _h6 = RegExp(r'^#{6} .*$', multiLine: true);
  static final RegExp _h5 = RegExp(r'^#{5} .*$', multiLine: true);
  static final RegExp _h4 = RegExp(r'^#{4} .*$', multiLine: true);
  static final RegExp _h3 = RegExp(r'^#{3} .*$', multiLine: true);
  static final RegExp _h2 = RegExp(r'^#{2} .*$', multiLine: true);
  static final RegExp _h1 = RegExp(r'^# .*$', multiLine: true);
  static final RegExp _blockquote = RegExp(r'^> .*$', multiLine: true);
  static final RegExp _hr = RegExp(
    r'^[ \t]*(---+|\*\*\*+|___+)[ \t]*$',
    multiLine: true,
  );
  static final RegExp _ul = RegExp(r'^[ \t]*[*+\-] .*$', multiLine: true);
  static final RegExp _ol = RegExp(r'^[ \t]*\d+\. .*$', multiLine: true);

  // Fenced code blocks – dotAll so `.` matches newlines inside the fence.
  static final RegExp _fencedCode = RegExp(
    r'^```[^\n]*\n[\s\S]*?^```[ \t]*$',
    multiLine: true,
  );

  // ── Inline regexes ───────────────────────────────────────────────────
  static final RegExp _reInlineCode = RegExp(r'`[^`\n]+`');
  static final RegExp _reBoldItalic = RegExp(
    r'(\*{3}|_{3})(?=\S)(.+?)(?<=\S)\1',
  );
  static final RegExp _reBold = RegExp(r'(\*{2}|_{2})(?=\S)(.+?)(?<=\S)\1');
  static final RegExp _reItalic = RegExp(r'(\*|_)(?=\S)(.+?)(?<=\S)\1');
  static final RegExp _reStrikethrough = RegExp(r'~~(?=\S)(.+?)(?<=\S)~~');
  static final RegExp _reImage = RegExp(r'!\[([^\]\n]*)\]\(([^)\n]*)\)');
  static final RegExp _reLink = RegExp(r'\[([^\]\n]*)\]\(([^)\n]*)\)');

  // ────────────────────────────────────────────────────────────────────
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> spans = _buildSpans(style);

    if (!withComposing ||
        !value.composing.isValid ||
        value.composing.isCollapsed) {
      return TextSpan(style: style, children: spans);
    }

    // Handle keyboard composing text (Gboard / iOS predictive input)
    return TextSpan(style: style, children: _applyComposing(spans));
  }

  // ── Main builder ─────────────────────────────────────────────────────

  List<TextSpan> _buildSpans(TextStyle? base) {
    final List<_Seg> segs = [];
    _processBlock(text, base, segs);
    return segs.map((s) => s.toSpan()).toList();
  }

  /// Process [src] for block-level patterns, appending [_Seg]s to [out].
  /// Non-block regions are forwarded to [_processInline].
  void _processBlock(String src, TextStyle? base, List<_Seg> out) {
    // All block patterns, ordered so more specific regexes win ties.
    final blockPatterns = <(RegExp, TextStyle? Function(TextStyle?))>[
      // Fenced code blocks – high priority, no inline parsing inside.
      (_fencedCode, (s) => _codeBlockStyle(s)),
      // Headings (most hashes first to avoid partial matches).
      (_h6, (s) => _headingStyle(s, 6)),
      (_h5, (s) => _headingStyle(s, 5)),
      (_h4, (s) => _headingStyle(s, 4)),
      (_h3, (s) => _headingStyle(s, 3)),
      (_h2, (s) => _headingStyle(s, 2)),
      (_h1, (s) => _headingStyle(s, 1)),
      // Other block elements.
      (_blockquote, (s) => _blockquoteStyle(s)),
      (_hr, (s) => _hrStyle(s)),
      (_ul, (s) => _listStyle(s)),
      (_ol, (s) => _listStyle(s)),
    ];

    // Collect every block match, tagging each with its style producer and
    // whether inline parsing should be suppressed (code blocks).
    final List<({int start, int end, TextStyle? style, bool noInline})>
    allMatches = [];

    for (final (regex, styleFn) in blockPatterns) {
      for (final m in regex.allMatches(src)) {
        final bool noInline = regex == _fencedCode;
        allMatches.add((
          start: m.start,
          end: m.end,
          style: styleFn(base),
          noInline: noInline,
        ));
      }
    }

    // Sort by start offset; earlier match wins, prefer longer match on ties.
    allMatches.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return b.end.compareTo(a.end); // longer first
    });

    int pos = 0;

    for (final match in allMatches) {
      if (match.start < pos) continue; // overlapped by a prior match

      // Text before this block match → inline parse.
      if (match.start > pos) {
        _processInline(src.substring(pos, match.start), base, out);
      }

      final String matchText = src.substring(match.start, match.end);
      if (match.noInline) {
        // Code blocks: emit as-is, no further parsing.
        // Keep trailing whitespace on the outer base style to prevent Flutter
        // from dropping it when the monospace span is the last on a line.
        final visibleBlock = matchText.trimRight();
        final trailingBlock = matchText.substring(visibleBlock.length);
        if (visibleBlock.isNotEmpty) out.add(_Seg(visibleBlock, match.style));
        if (trailingBlock.isNotEmpty) out.add(_Seg(trailingBlock, base));
      } else {
        // Other blocks: strip trailing whitespace, inline-parse the content,
        // then re-attach the trailing whitespace with the outer base style.
        // This prevents Flutter from dropping large-font trailing spaces.
        final visibleBlock = matchText.trimRight();
        final trailingBlock = matchText.substring(visibleBlock.length);
        _processInline(visibleBlock, match.style, out);
        if (trailingBlock.isNotEmpty) out.add(_Seg(trailingBlock, base));
      }

      pos = match.end;
    }

    // Remaining text after last block match.
    if (pos < src.length) {
      _processInline(src.substring(pos), base, out);
    }
  }

  /// Process [src] for inline patterns, appending [_Seg]s to [out].
  void _processInline(String src, TextStyle? base, List<_Seg> out) {
    // Collect all inline matches.
    final List<_InlineMatch> matches = [];

    void collect(RegExp re, _InlineKind kind) {
      for (final m in re.allMatches(src)) {
        matches.add(_InlineMatch(m.start, m.end, kind));
      }
    }

    collect(_reInlineCode, _InlineKind.inlineCode);
    collect(_reBoldItalic, _InlineKind.boldItalic);
    collect(_reBold, _InlineKind.bold);
    collect(_reItalic, _InlineKind.italic);
    collect(_reStrikethrough, _InlineKind.strikethrough);
    collect(_reImage, _InlineKind.image);
    collect(_reLink, _InlineKind.link);

    // Sort: earlier start wins; among ties, higher-priority kind wins.
    matches.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return a.kind.index.compareTo(b.kind.index);
    });

    int pos = 0;

    for (final m in matches) {
      if (m.start < pos) continue; // overlapped

      // Emit gap text directly – never split out trailing spaces here,
      // because Flutter drops trailing-whitespace spans that are the last
      // child of a RichText, which causes typed spaces to vanish.
      if (m.start > pos) {
        final gap = src.substring(pos, m.start);
        if (gap.isNotEmpty) out.add(_Seg(gap, base));
      }

      final String raw = src.substring(m.start, m.end);
      _emitInlineMatch(raw, m.kind, base, out);
      pos = m.end;
    }

    if (pos < src.length) {
      final tail = src.substring(pos);
      if (tail.isNotEmpty) out.add(_Seg(tail, base));
    }
  }

  /// Emit styled segments for a single inline match.
  void _emitInlineMatch(
    String raw,
    _InlineKind kind,
    TextStyle? base,
    List<_Seg> out,
  ) {
    final Color syntaxColor = (base?.color ?? Colors.black).withAlpha(100);
    final TextStyle dimSyntax = (base ?? const TextStyle()).copyWith(
      color: syntaxColor,
    );

    switch (kind) {
      case _InlineKind.fencedCode:
      case _InlineKind.inlineCode:
        out.add(_Seg(raw, _inlineCodeStyle(base)));

      case _InlineKind.boldItalic:
        final delim = raw.startsWith('***') ? '***' : '___';
        final inner = raw.substring(delim.length, raw.length - delim.length);
        out.add(_Seg(delim, dimSyntax));
        out.add(_Seg(inner, _boldItalicStyle(base)));
        out.add(_Seg(delim, dimSyntax));

      case _InlineKind.bold:
        final delim = raw.startsWith('**') ? '**' : '__';
        final inner = raw.substring(delim.length, raw.length - delim.length);
        out.add(_Seg(delim, dimSyntax));
        out.add(_Seg(inner, _boldStyle(base)));
        out.add(_Seg(delim, dimSyntax));

      case _InlineKind.italic:
        final delim = raw.startsWith('*') ? '*' : '_';
        final inner = raw.substring(delim.length, raw.length - delim.length);
        out.add(_Seg(delim, dimSyntax));
        out.add(_Seg(inner, _italicStyle(base)));
        out.add(_Seg(delim, dimSyntax));

      case _InlineKind.strikethrough:
        final inner = raw.substring(2, raw.length - 2);
        out.add(_Seg('~~', dimSyntax));
        out.add(_Seg(inner, _strikethroughStyle(base)));
        out.add(_Seg('~~', dimSyntax));

      case _InlineKind.image:
        // Show the full syntax dimmed – images can't be rendered inline.
        out.add(_Seg(raw, dimSyntax));

      case _InlineKind.link:
        // [text](url) – highlight link text, dim the rest.
        final bracketClose = raw.indexOf('](');
        if (bracketClose == -1) {
          out.add(_Seg(raw, base));
        } else {
          final linkText = raw.substring(1, bracketClose);
          final urlPart = raw.substring(bracketClose + 1); // ](url)
          out.add(_Seg('[', dimSyntax));
          out.add(_Seg(linkText, _linkStyle(base)));
          out.add(_Seg(urlPart, dimSyntax));
        }
    }
  }

  // ── Style helpers ─────────────────────────────────────────────────────

  static const double _baseFontSize = 16.0;

  TextStyle? _headingStyle(TextStyle? base, int level) {
    const scales = [1.8, 1.5, 1.3, 1.1, 1.0, 0.9];
    final scale = scales[level - 1];
    final baseSize = base?.fontSize ?? _baseFontSize;
    return (base ?? const TextStyle()).copyWith(
      fontSize: baseSize * scale,
      fontWeight: FontWeight.bold,
      height: 1.2,
      color: base?.color,
    );
  }

  TextStyle? _blockquoteStyle(TextStyle? base) {
    final color = (base?.color ?? Colors.black).withAlpha(160);
    return (base ?? const TextStyle()).copyWith(
      fontStyle: FontStyle.italic,
      color: color,
    );
  }

  TextStyle? _hrStyle(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      color: (base?.color ?? Colors.black).withAlpha(100),
      decoration: TextDecoration.lineThrough,
      decorationColor: (base?.color ?? Colors.black).withAlpha(120),
    );
  }

  TextStyle? _listStyle(TextStyle? base) => base;

  TextStyle? _codeBlockStyle(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      color: (base?.color ?? Colors.black).withAlpha(200),
    );
  }

  TextStyle? _inlineCodeStyle(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      color: base?.color,
    );
  }

  TextStyle? _boldStyle(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold);

  TextStyle? _italicStyle(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);

  TextStyle? _boldItalicStyle(TextStyle? base) => (base ?? const TextStyle())
      .copyWith(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic);

  TextStyle? _strikethroughStyle(TextStyle? base) => (base ?? const TextStyle())
      .copyWith(decoration: TextDecoration.lineThrough);

  TextStyle? _linkStyle(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        decorationColor: Colors.blue,
      );

  // ── Composing text overlay ────────────────────────────────────────────

  /// Overlay the IME composing underline on the already-styled spans.
  List<TextSpan> _applyComposing(List<TextSpan> spans) {
    final List<TextSpan> result = [];
    int pos = 0;
    final int composingStart = value.composing.start;
    final int composingEnd = value.composing.end;

    for (final span in spans) {
      final String spanText = span.text ?? '';
      final int spanLen = spanText.length;
      final int spanEnd = pos + spanLen;

      final int iStart = math.max(pos, composingStart);
      final int iEnd = math.min(spanEnd, composingEnd);

      if (iStart < iEnd) {
        // Before composing region.
        if (iStart > pos) {
          result.add(
            TextSpan(
              text: spanText.substring(0, iStart - pos),
              style: span.style,
            ),
          );
        }
        // Composing region.
        final TextStyle composingStyle =
            span.style?.merge(
              const TextStyle(decoration: TextDecoration.underline),
            ) ??
            const TextStyle(decoration: TextDecoration.underline);
        result.add(
          TextSpan(
            text: spanText.substring(iStart - pos, iEnd - pos),
            style: composingStyle,
          ),
        );
        // After composing region.
        if (iEnd < spanEnd) {
          result.add(
            TextSpan(text: spanText.substring(iEnd - pos), style: span.style),
          );
        }
      } else {
        result.add(span);
      }

      pos += spanLen;
    }

    return result;
  }
}
