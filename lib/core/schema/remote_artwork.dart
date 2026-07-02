import '../models/pixel_art.dart';
import 'firestore_paths.dart';

/// A remote (admin-published) artwork doc at `pixel_art/{flavor}/artworks/*`:
/// the full PixelArt JSON plus publishing metadata.
class RemoteArtwork {
  final PixelArt art;
  final bool visible;
  final int sortOrder;

  const RemoteArtwork({
    required this.art,
    this.visible = true,
    this.sortOrder = 0,
  });

  factory RemoteArtwork.fromMap(Map<String, dynamic> map) {
    return RemoteArtwork(
      art: PixelArt.fromJson(map),
      visible: map['visible'] as bool? ?? true,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...art.toJson(),
      'visible': visible,
      'sortOrder': sortOrder,
    };
  }

  /// Remote ids must be collision-proof against bundled ids.
  static bool hasRemoteId(String id) =>
      id.startsWith(FirestorePaths.remoteArtIdPrefix);
}
