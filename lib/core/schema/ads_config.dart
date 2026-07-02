/// Per-flavor ads configuration stored at `pixel_art/{flavor}/config/ads`.
///
/// All fields are nullable: an absent field means "no admin override" and the
/// app falls back to Remote Config, then to its hardcoded default. Plain map
/// serialization — no Firestore dependency.
class AdsConfig {
  final bool? showAds;
  final String? bannerAdUnitId;
  final String? interstitialAdUnitId;
  final String? rewardedAdUnitId;
  final String? appOpenAdUnitId;
  final int? interstitialCooldownS;
  final int? interstitialMinSessionS;
  final int? appOpenCooldownS;

  const AdsConfig({
    this.showAds,
    this.bannerAdUnitId,
    this.interstitialAdUnitId,
    this.rewardedAdUnitId,
    this.appOpenAdUnitId,
    this.interstitialCooldownS,
    this.interstitialMinSessionS,
    this.appOpenCooldownS,
  });

  /// The app's current production values (app_constants.dart /
  /// remote_config_service.dart) — shown as placeholders in the form.
  static const defaults = AdsConfig(
    showAds: true,
    bannerAdUnitId: 'ca-app-pub-9064606616675657/7511066180',
    interstitialAdUnitId: 'ca-app-pub-9064606616675657/6197984517',
    rewardedAdUnitId: 'ca-app-pub-9064606616675657/4884902843',
    appOpenAdUnitId: 'ca-app-pub-9064606616675657/4258216888',
    interstitialCooldownS: 90,
    interstitialMinSessionS: 120,
    appOpenCooldownS: 14400,
  );

  factory AdsConfig.fromMap(Map<String, dynamic> map) {
    return AdsConfig(
      showAds: map['showAds'] as bool?,
      bannerAdUnitId: _nonEmpty(map['bannerAdUnitId']),
      interstitialAdUnitId: _nonEmpty(map['interstitialAdUnitId']),
      rewardedAdUnitId: _nonEmpty(map['rewardedAdUnitId']),
      appOpenAdUnitId: _nonEmpty(map['appOpenAdUnitId']),
      interstitialCooldownS: _positive(map['interstitialCooldownS']),
      interstitialMinSessionS: _positive(map['interstitialMinSessionS']),
      appOpenCooldownS: _positive(map['appOpenCooldownS']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (showAds != null) 'showAds': showAds,
      if (bannerAdUnitId != null) 'bannerAdUnitId': bannerAdUnitId,
      if (interstitialAdUnitId != null)
        'interstitialAdUnitId': interstitialAdUnitId,
      if (rewardedAdUnitId != null) 'rewardedAdUnitId': rewardedAdUnitId,
      if (appOpenAdUnitId != null) 'appOpenAdUnitId': appOpenAdUnitId,
      if (interstitialCooldownS != null)
        'interstitialCooldownS': interstitialCooldownS,
      if (interstitialMinSessionS != null)
        'interstitialMinSessionS': interstitialMinSessionS,
      if (appOpenCooldownS != null) 'appOpenCooldownS': appOpenCooldownS,
    };
  }

  static String? _nonEmpty(Object? v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  static int? _positive(Object? v) {
    final n = (v as num?)?.toInt();
    return (n == null || n <= 0) ? null : n;
  }
}
