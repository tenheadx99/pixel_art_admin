/// Firestore collection/document paths — the contract between this admin
/// panel and the app. When the app later adds remote-config/catalog reading,
/// it must use these exact paths.
///
/// The Firebase project (om108-5c015) is shared with unrelated apps;
/// everything lives under the namespaced `pixel_art*` collections.
library;

class FirestorePaths {
  FirestorePaths._();

  /// Top-level content collection; one doc per flavor (id = flavor id).
  static const String root = 'pixel_art';

  /// Admin allowlist; doc id = Firebase Auth uid, created manually in console.
  static const String admins = 'pixel_art_admins';

  static String flavorDoc(String flavorId) => '$root/$flavorId';

  // config/* singleton docs under each flavor.
  static String adsConfigDoc(String flavorId) => '$root/$flavorId/config/ads';
  static String appConfigDoc(String flavorId) => '$root/$flavorId/config/app';
  static String economyConfigDoc(String flavorId) =>
      '$root/$flavorId/config/economy';

  /// Remote (admin-published) artworks. Doc ids carry [remoteArtIdPrefix].
  static String artworksCol(String flavorId) => '$root/$flavorId/artworks';

  /// Sparse metadata overrides for bundled artworks (doc id = bundled art id).
  static String overridesCol(String flavorId) => '$root/$flavorId/overrides';

  /// Admin-only mirror of the app's bundled assets, seeded by
  /// tool/seed_bundled_index.py. The app never reads this.
  static String bundledIndexCol(String flavorId) =>
      '$root/$flavorId/bundled_index';

  /// Remote artwork ids are prefixed so they can never collide with bundled
  /// ids (which also keeps the app's per-art SharedPreferences keys stable).
  static const String remoteArtIdPrefix = 'rmt_';
}

/// Fields on the flavor root doc.
class FlavorDocFields {
  FlavorDocFields._();

  /// Monotonic int bumped by every catalog mutation; the app refetches the
  /// catalog only when this exceeds its cached version.
  static const String catalogVersion = 'catalogVersion';
  static const String updatedAt = 'updatedAt';
}
