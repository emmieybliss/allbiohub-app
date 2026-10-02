/// One rendition of an image (WordPress generates several sizes per upload).
class ImageVariant {
  const ImageVariant({
    required this.url,
    required this.width,
    required this.height,
  });

  factory ImageVariant.fromJson(Map<String, dynamic> json) => ImageVariant(
    url: json['url'] as String,
    width: json['w'] as int? ?? 0,
    height: json['h'] as int? ?? 0,
  );

  final String url;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {'url': url, 'w': width, 'h': height};
}

/// An image with all its available sizes, so widgets can download the
/// smallest file that still looks sharp.
class MediaImage {
  const MediaImage({required this.variants, this.alt = '', this.caption = ''});

  factory MediaImage.single(String url, {String alt = ''}) => MediaImage(
    variants: [ImageVariant(url: url, width: 0, height: 0)],
    alt: alt,
  );

  factory MediaImage.fromJson(Map<String, dynamic> json) => MediaImage(
    variants: (json['v'] as List<dynamic>)
        .map((e) => ImageVariant.fromJson(e as Map<String, dynamic>))
        .toList(),
    alt: json['alt'] as String? ?? '',
    caption: json['cap'] as String? ?? '',
  );

  /// Sorted smallest to largest; variants with unknown width (0) come last.
  final List<ImageVariant> variants;
  final String alt;
  final String caption;

  ImageVariant get largest => variants.last;

  /// Aspect ratio of the largest (uncropped) rendition.
  double? get aspectRatio {
    final v = variants.lastWhere(
      (v) => v.width > 0 && v.height > 0,
      orElse: () => variants.last,
    );
    return v.width > 0 && v.height > 0 ? v.width / v.height : null;
  }

  /// Smallest variant at least [physicalWidth] pixels wide, or the largest.
  /// Cropped square thumbnails are only used when [allowCropped] is set.
  String urlFor(double physicalWidth, {bool allowCropped = false}) {
    final ratio = aspectRatio;
    for (final v in variants) {
      if (v.width == 0) continue;
      final cropped =
          ratio != null &&
          v.height > 0 &&
          ((v.width / v.height) - ratio).abs() > 0.05;
      if (cropped && !allowCropped) continue;
      if (v.width >= physicalWidth) return v.url;
    }
    return variants
        .lastWhere((v) => v.width > 0, orElse: () => variants.last)
        .url;
  }

  Map<String, dynamic> toJson() => {
    'v': variants.map((v) => v.toJson()).toList(),
    'alt': alt,
    'cap': caption,
  };
}
