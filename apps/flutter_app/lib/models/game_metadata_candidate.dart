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
    this.alternativeTitles = const [],
    this.details,
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

  /// Other useful localized titles, ordered for the current app locale.
  /// The selected [title] itself is not repeated here.
  final List<String> alternativeTitles;

  /// Metadata that is intentionally fetched only after this candidate has
  /// been selected. Search results leave this null to keep their request
  /// lightweight.
  final GameMetadataDetails? details;

  GameMetadataCandidate copyWith({GameMetadataDetails? details}) {
    return GameMetadataCandidate(
      title: title,
      coverImageUrl: coverImageUrl,
      thumbnailUrl: thumbnailUrl,
      coverImageDimensions: coverImageDimensions,
      thumbnailDimensions: thumbnailDimensions,
      developer: developer,
      sourceId: sourceId,
      sourceLabel: sourceLabel,
      alternativeTitles: alternativeTitles,
      details: details ?? this.details,
    );
  }
}

/// Additional fields returned by a provider's per-game details request.
class GameMetadataDetails {
  const GameMetadataDetails({this.description, this.keywords = const []});

  final String? description;

  /// Provider tags ordered from most relevant to least relevant.
  final List<String> keywords;
}

/// Pixel dimensions of an image returned by a metadata provider.
class GameImageDimensions {
  const GameImageDimensions({required this.width, required this.height});

  final int width;
  final int height;

  double get aspectRatio => width / height;
}
