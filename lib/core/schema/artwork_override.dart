/// Sparse metadata override for a BUNDLED artwork, stored at
/// `pixel_art/{flavor}/overrides/{bundledArtId}`. Only set fields apply;
/// grid data is never overridden.
class ArtworkOverride {
  final String artId;
  final bool? hidden;
  final bool? isPremium;
  final String? category;
  final int? sortOrder;

  const ArtworkOverride({
    required this.artId,
    this.hidden,
    this.isPremium,
    this.category,
    this.sortOrder,
  });

  bool get isEmpty =>
      hidden == null &&
      isPremium == null &&
      category == null &&
      sortOrder == null;

  factory ArtworkOverride.fromMap(String artId, Map<String, dynamic> map) {
    final cat = map['category'] as String?;
    return ArtworkOverride(
      artId: artId,
      hidden: map['hidden'] as bool?,
      isPremium: map['isPremium'] as bool?,
      category: (cat == null || cat.isEmpty) ? null : cat,
      sortOrder: (map['sortOrder'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (hidden != null) 'hidden': hidden,
      if (isPremium != null) 'isPremium': isPremium,
      if (category != null) 'category': category,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
  }
}
