/// A single scraping result candidate (e.g. from VNDB).
/// Used for search list display and cover download.
class GameMetadataCandidate {
  const GameMetadataCandidate({
    required this.title,
    required this.coverImageUrl,
    this.thumbnailUrl,
    this.coverImageDimensions,
    this.thumbnailDimensions,
    this.developer,
    this.sourceId,
    this.sourceLabel,
  });

  final String title;
  final String coverImageUrl;

  /// Optional thumbnail URL. Used as fallback when full cover fails (e.g. 403 for R18).
  final String? thumbnailUrl;

  /// Dimensions reported by the metadata provider for the full-size cover.
  final GameImageDimensions? coverImageDimensions;

  /// Dimensions reported by the metadata provider for the thumbnail.
  final GameImageDimensions? thumbnailDimensions;

  /// Developer / producer name (e.g. from VNDB).
  final String? developer;
  final String? sourceId;
  final String? sourceLabel;
}

/// Pixel dimensions of an image returned by a metadata provider.
class GameImageDimensions {
  const GameImageDimensions({required this.width, required this.height});

  final int width;
  final int height;

  double get aspectRatio => width / height;
}
