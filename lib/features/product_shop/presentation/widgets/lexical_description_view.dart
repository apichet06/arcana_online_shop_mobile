import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class LexicalDescriptionView extends StatelessWidget {
  const LexicalDescriptionView({
    super.key,
    required this.value,
    required this.resolveImageUrl,
  });

  final String value;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is! Map<String, dynamic>) return Text(trimmed);

      final root = _asMap(parsed['root']);
      final children = _asNodeList(root['children']);
      if (children.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final node in children) _LexicalNodeView(node: node, resolveImageUrl: resolveImageUrl),
        ],
      );
    } catch (_) {
      return Text(trimmed, style: Theme.of(context).textTheme.bodyMedium);
    }
  }
}

class _LexicalNodeView extends StatelessWidget {
  const _LexicalNodeView({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final type = node['type']?.toString();

    switch (type) {
      case 'heading':
        return _HeadingNodeView(node: node, resolveImageUrl: resolveImageUrl);
      case 'paragraph':
        return _ParagraphNodeView(node: node, resolveImageUrl: resolveImageUrl);
      case 'quote':
        return _QuoteNodeView(node: node, resolveImageUrl: resolveImageUrl);
      case 'list':
        return _ListNodeView(node: node, resolveImageUrl: resolveImageUrl);
      case 'image':
        return _ImageNodeView(node: node, resolveImageUrl: resolveImageUrl);
      case 'youtube':
        return _YoutubeNodeView(node: node);
      case 'tiktok':
        return _TikTokNodeView(node: node);
      case 'layout-container':
      case 'layout-item':
      case 'root':
        return _ChildrenColumn(node: node, resolveImageUrl: resolveImageUrl);
      case 'table':
        return _TableFallbackView(node: node);
      default:
        final text = _plainText(node).trim();
        if (text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        );
    }
  }
}

class _HeadingNodeView extends StatelessWidget {
  const _HeadingNodeView({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final tag = node['tag']?.toString();
    final theme = Theme.of(context).textTheme;
    final style = switch (tag) {
      'h1' => theme.headlineSmall,
      'h2' => theme.titleLarge,
      'h3' => theme.titleMedium,
      _ => theme.titleMedium,
    };
    final blockChildren = _embeddedBlockChildren(node);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: _crossAxisAlignmentFromFormat(node),
        children: [
          if (_plainText(node).trim().isNotEmpty)
            Text.rich(
              TextSpan(
                children: _inlineSpans(
                  node,
                  baseStyle: style,
                  resolveImageUrl: resolveImageUrl,
                ),
              ),
              textAlign: _textAlignFromFormat(node),
              style: style?.copyWith(fontWeight: FontWeight.w800),
            ),
          for (final child in blockChildren)
            _LexicalNodeView(
              node: child,
              resolveImageUrl: resolveImageUrl,
            ),
        ],
      ),
    );
  }
}

class _YoutubeNodeView extends StatelessWidget {
  const _YoutubeNodeView({required this.node});

  final Map<String, dynamic> node;

  @override
  Widget build(BuildContext context) {
    final url = _youtubeUrlFromNode(node);
    if (url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _YoutubeEmbed(url: url),
    );
  }
}

class _TikTokNodeView extends StatelessWidget {
  const _TikTokNodeView({required this.node});

  final Map<String, dynamic> node;

  @override
  Widget build(BuildContext context) {
    final url = _tiktokUrlFromNode(node);
    if (url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _TikTokEmbed(url: url),
    );
  }
}

class _EmbeddedBlockColumn extends StatelessWidget {
  const _EmbeddedBlockColumn({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final children = _embeddedBlockChildren(node);
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: _crossAxisAlignmentFromFormat(node),
      children: [
        for (final child in children)
          _LexicalNodeView(
            node: child,
            resolveImageUrl: resolveImageUrl,
          ),
      ],
    );
  }
}

class _ParagraphNodeView extends StatelessWidget {
  const _ParagraphNodeView({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final mediaLinks = _mediaLinksFromNode(node);
    final blockChildren = _embeddedBlockChildren(node);
    final spans = _inlineSpans(
      node,
      baseStyle: Theme.of(context).textTheme.bodyMedium,
      resolveImageUrl: resolveImageUrl,
    );
    if (spans.isEmpty || _plainText(node).trim().isEmpty) {
      if (mediaLinks.isEmpty && blockChildren.isEmpty) {
        return const SizedBox(height: 8);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: _crossAxisAlignmentFromFormat(node),
        children: [
          if (spans.isNotEmpty && _plainText(node).trim().isNotEmpty)
            Text.rich(
              TextSpan(children: spans),
              textAlign: _textAlignFromFormat(node),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.55,
              ),
            ),
          _EmbeddedBlockColumn(node: node, resolveImageUrl: resolveImageUrl),
          for (final media in mediaLinks) _MediaEmbedView(media: media),
        ],
      ),
    );
  }
}

class _QuoteNodeView extends StatelessWidget {
  const _QuoteNodeView({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(width: 4, color: Color(0xFFCBD5E1))),
      ),
      child: Text.rich(
        TextSpan(
          children: _inlineSpans(
            node,
            baseStyle: Theme.of(context).textTheme.bodyMedium,
            resolveImageUrl: resolveImageUrl,
          ),
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF475569),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _ListNodeView extends StatelessWidget {
  const _ListNodeView({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final children = _asNodeList(node['children']);
    if (children.isEmpty) return const SizedBox.shrink();

    final listType = node['listType']?.toString();
    final isNumbered = listType == 'number';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++)
            _ListItemView(
              node: children[i],
              marker: isNumbered ? '${i + 1}.' : '•',
              resolveImageUrl: resolveImageUrl,
            ),
        ],
      ),
    );
  }
}

class _ListItemView extends StatelessWidget {
  const _ListItemView({
    required this.node,
    required this.marker,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String marker;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final text = _plainText(node).trim();
    final nestedBlocks = _asNodeList(node['children']).where((child) {
      final type = child['type']?.toString();
      return type == 'list' || _isEmbeddedBlockType(type);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(marker, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
          for (final child in nestedBlocks)
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: _LexicalNodeView(node: child, resolveImageUrl: resolveImageUrl),
            ),
        ],
      ),
    );
  }
}

class _ImageNodeView extends StatelessWidget {
  const _ImageNodeView({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final src = _resolveLexicalImageUrl(
      node['src']?.toString(),
      resolveImageUrl,
    );
    if (src.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          src,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _MediaEmbedView extends StatelessWidget {
  const _MediaEmbedView({required this.media});

  final _MediaLink media;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: switch (media.type) {
        _MediaType.youtube => _YoutubeEmbed(url: media.url),
        _MediaType.tiktok => _TikTokEmbed(url: media.url),
      },
    );
  }
}

class _YoutubeEmbed extends StatefulWidget {
  const _YoutubeEmbed({required this.url});

  final String url;

  @override
  State<_YoutubeEmbed> createState() => _YoutubeEmbedState();
}

class _YoutubeEmbedState extends State<_YoutubeEmbed> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final videoId = _youtubeVideoId(widget.url);
    if (videoId == null) return;

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _UnsupportedMediaCard(
        title: 'ไม่สามารถแสดงวิดีโอ YouTube นี้ได้',
        url: widget.url,
        icon: Icons.play_disabled_outlined,
      );
    }

    return _MediaFrame(
      title: 'YouTube',
      icon: Icons.play_circle_outline,
      accentColor: const Color(0xFFDC2626),
      child: YoutubePlayer(
        controller: controller,
        aspectRatio: 16 / 9,
      ),
    );
  }
}

class _TikTokEmbed extends StatefulWidget {
  const _TikTokEmbed({required this.url});

  final String url;

  @override
  State<_TikTokEmbed> createState() => _TikTokEmbedState();
}

class _TikTokEmbedState extends State<_TikTokEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final embedHeight = screenHeight.clamp(480.0, 620.0).toDouble();

    return _MediaFrame(
      title: 'TikTok',
      icon: Icons.music_video_outlined,
      accentColor: const Color(0xFF111827),
      isVerticalMedia: true,
      child: SizedBox(
        height: embedHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.isVerticalMedia = false,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final bool isVerticalMedia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: isVerticalMedia ? 340 : double.infinity,
              constraints: BoxConstraints(
                maxWidth: isVerticalMedia ? 360 : double.infinity,
              ),
              padding: isVerticalMedia ? const EdgeInsets.all(8) : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isVerticalMedia
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: isVerticalMedia
                    ? const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedMediaCard extends StatelessWidget {
  const _UnsupportedMediaCard({
    required this.title,
    required this.url,
    required this.icon,
  });

  final String title;
  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MediaType { youtube, tiktok }

class _MediaLink {
  const _MediaLink({
    required this.url,
    required this.type,
  });

  final String url;
  final _MediaType type;
}

class _ChildrenColumn extends StatelessWidget {
  const _ChildrenColumn({
    required this.node,
    required this.resolveImageUrl,
  });

  final Map<String, dynamic> node;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final children = _asNodeList(node['children']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in children) _LexicalNodeView(node: child, resolveImageUrl: resolveImageUrl),
      ],
    );
  }
}

class _TableFallbackView extends StatelessWidget {
  const _TableFallbackView({required this.node});

  final Map<String, dynamic> node;

  @override
  Widget build(BuildContext context) {
    final text = _plainText(node).trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

List<InlineSpan> _inlineSpans(
  Map<String, dynamic> node, {
  required TextStyle? baseStyle,
  required String Function(String? value) resolveImageUrl,
}) {
  final spans = <InlineSpan>[];

  for (final child in _asNodeList(node['children'])) {
    final type = child['type']?.toString();

    if (type == 'text') {
      spans.add(
        TextSpan(
          text: child['text']?.toString() ?? '',
          style: _textStyleFromFormat(baseStyle, child['format']),
        ),
      );
      continue;
    }

    if (type == 'linebreak') {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }

    if (type == 'link' || type == 'autolink') {
      spans.addAll(
        _inlineSpans(
          child,
          baseStyle: baseStyle?.copyWith(
            color: const Color(0xFF0369A1),
            decoration: TextDecoration.underline,
          ),
          resolveImageUrl: resolveImageUrl,
        ),
      );
      continue;
    }

    spans.addAll(
      _inlineSpans(
        child,
        baseStyle: baseStyle,
        resolveImageUrl: resolveImageUrl,
      ),
    );
  }

  return spans;
}

List<Map<String, dynamic>> _embeddedBlockChildren(Map<String, dynamic> node) {
  return _asNodeList(node['children'])
      .where((child) => _isEmbeddedBlockType(child['type']?.toString()))
      .toList();
}

bool _isEmbeddedBlockType(String? type) {
  return type == 'image' || type == 'youtube' || type == 'tiktok';
}

TextAlign _textAlignFromFormat(Map<String, dynamic> node) {
  return switch (node['format']?.toString()) {
    'center' => TextAlign.center,
    'right' || 'end' => TextAlign.right,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

CrossAxisAlignment _crossAxisAlignmentFromFormat(Map<String, dynamic> node) {
  return switch (node['format']?.toString()) {
    'center' => CrossAxisAlignment.center,
    'right' || 'end' => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.start,
  };
}

List<_MediaLink> _mediaLinksFromNode(Map<String, dynamic> node) {
  final links = <_MediaLink>[];
  final seen = <String>{};

  void visit(Map<String, dynamic> current) {
    final type = current['type']?.toString();
    final url = type == 'link' || type == 'autolink'
        ? current['url']?.toString()
        : null;

    final media = _mediaFromUrl(url);
    if (media != null && seen.add(media.url)) {
      links.add(media);
    }

    for (final child in _asNodeList(current['children'])) {
      visit(child);
    }

    if (type == 'text') {
      final text = current['text']?.toString() ?? '';
      for (final match in _urlPattern.allMatches(text)) {
        final media = _mediaFromUrl(match.group(0));
        if (media != null && seen.add(media.url)) {
          links.add(media);
        }
      }
    }
  }

  visit(node);
  return links;
}

final RegExp _urlPattern = RegExp(
  r'''https?:\/\/[^\s<>"']+''',
  caseSensitive: false,
);

_MediaLink? _mediaFromUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final normalized = value.trim();
  final uri = Uri.tryParse(normalized);
  final host = uri?.host.toLowerCase() ?? '';

  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return _MediaLink(
      url: normalized,
      type: _MediaType.youtube,
    );
  }

  if (host.contains('tiktok.com')) {
    return _MediaLink(
      url: normalized,
      type: _MediaType.tiktok,
    );
  }

  return null;
}

String _youtubeUrlFromNode(Map<String, dynamic> node) {
  final directUrl = node['url']?.toString() ?? node['src']?.toString();
  if (directUrl != null && directUrl.isNotEmpty) return directUrl;

  final videoId =
      node['videoId']?.toString() ??
      node['videoID']?.toString() ??
      node['id']?.toString();
  if (videoId == null || videoId.isEmpty) return '';

  return 'https://www.youtube.com/watch?v=$videoId';
}

String _tiktokUrlFromNode(Map<String, dynamic> node) {
  final directUrl = node['url']?.toString() ?? node['src']?.toString();
  if (directUrl != null && directUrl.isNotEmpty) return directUrl;

  final videoId =
      node['videoId']?.toString() ??
      node['videoID']?.toString() ??
      node['id']?.toString();
  if (videoId == null || videoId.isEmpty) return '';

  return 'https://www.tiktok.com/embed/v2/$videoId';
}

String? _youtubeVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }

  if (!host.contains('youtube.com')) return null;
  final queryId = uri.queryParameters['v'];
  if (queryId != null && queryId.isNotEmpty) return queryId;

  final segments = uri.pathSegments;
  final shortsIndex = segments.indexOf('shorts');
  if (shortsIndex >= 0 && segments.length > shortsIndex + 1) {
    return segments[shortsIndex + 1];
  }

  final embedIndex = segments.indexOf('embed');
  if (embedIndex >= 0 && segments.length > embedIndex + 1) {
    return segments[embedIndex + 1];
  }

  return null;
}

TextStyle? _textStyleFromFormat(TextStyle? baseStyle, Object? formatValue) {
  if (baseStyle == null) return null;

  final format = formatValue is int ? formatValue : int.tryParse(formatValue?.toString() ?? '') ?? 0;

  return baseStyle.copyWith(
    fontWeight: _hasFormat(format, 1) ? FontWeight.w800 : baseStyle.fontWeight,
    fontStyle: _hasFormat(format, 2) ? FontStyle.italic : baseStyle.fontStyle,
    decoration: _hasFormat(format, 8) ? TextDecoration.underline : baseStyle.decoration,
  );
}

String _plainText(Map<String, dynamic> node) {
  final type = node['type']?.toString();
  if (type == 'text') return node['text']?.toString() ?? '';
  if (type == 'linebreak') return '\n';

  final buffer = StringBuffer();
  for (final child in _asNodeList(node['children'])) {
    final text = _plainText(child);
    if (text.isEmpty) continue;
    if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
      buffer.write(' ');
    }
    buffer.write(text);
  }

  return buffer.toString();
}

bool _hasFormat(int format, int flag) => (format & flag) != 0;

String _resolveLexicalImageUrl(
  String? value,
  String Function(String? value) resolveImageUrl,
) {
  if (value == null || value.isEmpty) return '';
  if (value.startsWith('data:') || value.startsWith('blob:')) return value;

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    final lowerPath = uri.path.toLowerCase();
    final uploadsIndex = lowerPath.lastIndexOf('/uploads/');
    if (uploadsIndex >= 0) {
      return resolveImageUrl(uri.path.substring(uploadsIndex));
    }

    return value;
  }

  return resolveImageUrl(value);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return const {};
}

List<Map<String, dynamic>> _asNodeList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}
