import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/media_image.dart';
import '../../core/theme/app_theme.dart';

/// Network image that downloads the smallest WordPress size that is sharp at
/// the rendered width, caches it on disk, decodes it at display size, and
/// degrades to a branded placeholder when missing or broken.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.image,
    this.aspectRatio,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.allowCropped = false,
    this.placeholderIcon = Icons.image_outlined,
    this.semanticLabel,
  });

  final MediaImage? image;
  final double? aspectRatio;
  final BorderRadius borderRadius;
  final BoxFit fit;

  /// Allow WordPress' square-cropped thumbnail sizes (fine for small squares).
  final bool allowCropped;
  final IconData placeholderIcon;
  final String? semanticLabel;

  /// Widget tests set this to render placeholders instead of downloading.
  @visibleForTesting
  static bool disableNetwork = false;

  @override
  Widget build(BuildContext context) {
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final img = image;
        if (img == null || disableNetwork) {
          return _Placeholder(icon: placeholderIcon);
        }
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 400.0;
        final physical = (width * dpr).clamp(64.0, 2048.0);
        final url = img.urlFor(physical, allowCropped: allowCropped);
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: physical.round(),
          fadeInDuration: const Duration(milliseconds: 220),
          placeholder: (_, _) => const _Placeholder(),
          errorWidget: (_, _, _) => _Placeholder(icon: placeholderIcon),
        );
      },
    );
    final label = semanticLabel ?? image?.alt;
    final framed = ClipRRect(
      borderRadius: borderRadius,
      child: Semantics(
        image: true,
        label: label == null || label.isEmpty ? null : label,
        excludeSemantics: true,
        child: child,
      ),
    );
    final ratio = aspectRatio;
    return ratio == null
        ? framed
        : AspectRatio(aspectRatio: ratio, child: framed);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ColoredBox(
      color: brand.skeleton,
      child: icon == null
          ? const SizedBox.expand()
          : Center(child: Icon(icon, color: brand.subtle, size: 28)),
    );
  }
}
