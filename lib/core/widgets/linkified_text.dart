import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final _urlPattern = RegExp(r'https?://[^\s<>()]+');

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final defaultStyle = DefaultTextStyle.of(context).style;
    final fallbackColor =
        Theme.of(context).textTheme.bodyMedium?.color ??
        Theme.of(context).colorScheme.onSurface;
    final baseStyle = defaultStyle
        .merge(widget.style)
        .copyWith(
          color: widget.style?.color ?? defaultStyle.color ?? fallbackColor,
        );
    final linkStyle =
        widget.linkStyle ??
        baseStyle.copyWith(
          color: const Color(0xFF0A66C2),
          fontWeight: FontWeight.w700,
        );

    return RichText(
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      text: TextSpan(style: baseStyle, children: _spans(baseStyle, linkStyle)),
    );
  }

  List<InlineSpan> _spans(TextStyle baseStyle, TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: widget.text.substring(index, match.start)));
      }
      final raw = match.group(0)!;
      final split = _splitTrailingPunctuation(raw);
      final url = split.$1;
      final trailing = split.$2;
      final recognizer = TapGestureRecognizer()..onTap = () => _openUrl(url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: url, style: linkStyle, recognizer: recognizer));
      if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      index = match.end;
    }
    if (index < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(index)));
    }
    return spans;
  }

  (String, String) _splitTrailingPunctuation(String value) {
    var url = value;
    var trailing = '';
    while (url.isNotEmpty && '.,;:!?)]}'.contains(url[url.length - 1])) {
      trailing = url[url.length - 1] + trailing;
      url = url.substring(0, url.length - 1);
    }
    return (url, trailing);
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}
