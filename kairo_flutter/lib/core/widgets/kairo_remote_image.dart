import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Loads a stored media ref (public URL, signed URL, or object path).
/// Falls back to the original value if signing is unavailable.
class KairoRemoteImage extends StatefulWidget {
  const KairoRemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  @override
  State<KairoRemoteImage> createState() => _KairoRemoteImageState();
}

class _KairoRemoteImageState extends State<KairoRemoteImage> {
  late String _url;

  @override
  void initState() {
    super.initState();
    _url = widget.url;
    _resolve();
  }

  @override
  void didUpdateWidget(covariant KairoRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _url = widget.url;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final next = await StorageService().resolveDisplayUrl(widget.url);
    if (!mounted || next == _url) return;
    setState(() => _url = next);
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: widget.fadeOutDuration,
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget,
    );
  }
}
