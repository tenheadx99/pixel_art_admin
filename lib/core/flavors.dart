import 'dart:ui' show Color;

/// Flavor identity — must stay in sync with the app's
/// pixel_art_app/lib/config/flavor.dart. These ids are the Firestore flavor
/// doc ids and the `--dart-define=FLAVOR=` values.
class Flavor {
  final String id;
  final String displayName;
  final String androidAppId;
  final bool gemStyle;
  final Color brandColor;

  const Flavor({
    required this.id,
    required this.displayName,
    required this.androidAppId,
    this.gemStyle = false,
    required this.brandColor,
  });
}

const List<Flavor> kFlavors = [
  Flavor(
    id: 'original',
    displayName: 'Pixely',
    androidAppId: 'com.tenhead.pixelyart',
    brandColor: Color(0xFF8A2BE2),
  ),
  Flavor(
    id: 'devotional',
    displayName: 'Divine Pixels',
    androidAppId: 'com.tenhead.divinepixels',
    brandColor: Color(0xFFFF6D00),
  ),
  Flavor(
    id: 'anime',
    displayName: 'Anime Pixels',
    androidAppId: 'com.tenhead.animepixels',
    brandColor: Color(0xFFFF4FA3),
  ),
  Flavor(
    id: 'pixelcalm',
    displayName: 'PixelCalm',
    androidAppId: 'com.tenhead.pixelcalm',
    brandColor: Color(0xFF7C9070),
  ),
  Flavor(
    id: 'diamond',
    displayName: 'Gem Art',
    androidAppId: 'com.tenhead.gemart',
    gemStyle: true,
    brandColor: Color(0xFF12C2E9),
  ),
];

Flavor flavorById(String id) => kFlavors.firstWhere((f) => f.id == id);

/// Remote Config key prefix. The original flavor predates the flavor system
/// and kept its `pixelyart` prefix; every other flavor uses its own name.
/// Mirrors `FlavorConfig.getFlavorKey` in the app.
String rcKeyPrefix(String flavorId) =>
    flavorId == 'original' ? 'pixelyart' : flavorId;
