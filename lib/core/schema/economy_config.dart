/// Per-flavor economy tuning stored at `pixel_art/{flavor}/config/economy`.
///
/// Every field is non-null: [EconomyConfig.defaults] mirrors the app's
/// historical `AppConstants` values, and [fromMap] falls back to them
/// per-field, so a partial or missing doc is always safe.
class EconomyConfig {
  // Earning.
  final int startingDiamonds;
  final int diamondsPerCompletion;
  final int diamondsDailyBonus;
  final int diamondsPerLevelUp;
  final int diamondsPerAchievement;
  final int doubleRewardMultiplier;

  // Shop prices (in diamonds).
  final int diamondCostUnlockArt;
  final int diamondCostHint;
  final int diamondCostWand;
  final int diamondCostBomb;
  final int diamondCostBrush;

  // Rewarded-ad and IAP grants.
  final int hintsPerRewardedAd;
  final int wandsPerRewardedAd;
  final int hintsPerPurchase;
  final int wandsPerPurchase;

  // XP & levels.
  final int xpPerCell;
  final int xpPerCompletion;
  final int xpLevelDivisor;

  // In-artwork milestone gifts (30% / 65% / 100%).
  final int milestone30Bomb;
  final int milestone65Diamonds;
  final int milestone100Diamonds;

  const EconomyConfig({
    required this.startingDiamonds,
    required this.diamondsPerCompletion,
    required this.diamondsDailyBonus,
    required this.diamondsPerLevelUp,
    required this.diamondsPerAchievement,
    required this.doubleRewardMultiplier,
    required this.diamondCostUnlockArt,
    required this.diamondCostHint,
    required this.diamondCostWand,
    required this.diamondCostBomb,
    required this.diamondCostBrush,
    required this.hintsPerRewardedAd,
    required this.wandsPerRewardedAd,
    required this.hintsPerPurchase,
    required this.wandsPerPurchase,
    required this.xpPerCell,
    required this.xpPerCompletion,
    required this.xpLevelDivisor,
    required this.milestone30Bomb,
    required this.milestone65Diamonds,
    required this.milestone100Diamonds,
  });

  /// The app's hardcoded values (pixel_art_app/lib/config/app_constants.dart).
  static const EconomyConfig defaults = EconomyConfig(
    startingDiamonds: 320,
    diamondsPerCompletion: 50,
    diamondsDailyBonus: 25,
    diamondsPerLevelUp: 50,
    diamondsPerAchievement: 15,
    doubleRewardMultiplier: 2,
    diamondCostUnlockArt: 200,
    diamondCostHint: 30,
    diamondCostWand: 40,
    diamondCostBomb: 40,
    diamondCostBrush: 40,
    hintsPerRewardedAd: 3,
    wandsPerRewardedAd: 2,
    hintsPerPurchase: 5,
    wandsPerPurchase: 10,
    xpPerCell: 1,
    xpPerCompletion: 100,
    xpLevelDivisor: 100,
    milestone30Bomb: 1,
    milestone65Diamonds: 20,
    milestone100Diamonds: 30,
  );

  factory EconomyConfig.fromMap(Map<String, dynamic> map) {
    int f(String key, int fallback) {
      final v = (map[key] as num?)?.toInt();
      return (v == null || v < 0) ? fallback : v;
    }

    const d = defaults;
    return EconomyConfig(
      startingDiamonds: f('startingDiamonds', d.startingDiamonds),
      diamondsPerCompletion:
          f('diamondsPerCompletion', d.diamondsPerCompletion),
      diamondsDailyBonus: f('diamondsDailyBonus', d.diamondsDailyBonus),
      diamondsPerLevelUp: f('diamondsPerLevelUp', d.diamondsPerLevelUp),
      diamondsPerAchievement:
          f('diamondsPerAchievement', d.diamondsPerAchievement),
      doubleRewardMultiplier:
          f('doubleRewardMultiplier', d.doubleRewardMultiplier),
      diamondCostUnlockArt: f('diamondCostUnlockArt', d.diamondCostUnlockArt),
      diamondCostHint: f('diamondCostHint', d.diamondCostHint),
      diamondCostWand: f('diamondCostWand', d.diamondCostWand),
      diamondCostBomb: f('diamondCostBomb', d.diamondCostBomb),
      diamondCostBrush: f('diamondCostBrush', d.diamondCostBrush),
      hintsPerRewardedAd: f('hintsPerRewardedAd', d.hintsPerRewardedAd),
      wandsPerRewardedAd: f('wandsPerRewardedAd', d.wandsPerRewardedAd),
      hintsPerPurchase: f('hintsPerPurchase', d.hintsPerPurchase),
      wandsPerPurchase: f('wandsPerPurchase', d.wandsPerPurchase),
      xpPerCell: f('xpPerCell', d.xpPerCell),
      xpPerCompletion: f('xpPerCompletion', d.xpPerCompletion),
      xpLevelDivisor: f('xpLevelDivisor', d.xpLevelDivisor),
      milestone30Bomb: f('milestone30Bomb', d.milestone30Bomb),
      milestone65Diamonds: f('milestone65Diamonds', d.milestone65Diamonds),
      milestone100Diamonds: f('milestone100Diamonds', d.milestone100Diamonds),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startingDiamonds': startingDiamonds,
      'diamondsPerCompletion': diamondsPerCompletion,
      'diamondsDailyBonus': diamondsDailyBonus,
      'diamondsPerLevelUp': diamondsPerLevelUp,
      'diamondsPerAchievement': diamondsPerAchievement,
      'doubleRewardMultiplier': doubleRewardMultiplier,
      'diamondCostUnlockArt': diamondCostUnlockArt,
      'diamondCostHint': diamondCostHint,
      'diamondCostWand': diamondCostWand,
      'diamondCostBomb': diamondCostBomb,
      'diamondCostBrush': diamondCostBrush,
      'hintsPerRewardedAd': hintsPerRewardedAd,
      'wandsPerRewardedAd': wandsPerRewardedAd,
      'hintsPerPurchase': hintsPerPurchase,
      'wandsPerPurchase': wandsPerPurchase,
      'xpPerCell': xpPerCell,
      'xpPerCompletion': xpPerCompletion,
      'xpLevelDivisor': xpLevelDivisor,
      'milestone30Bomb': milestone30Bomb,
      'milestone65Diamonds': milestone65Diamonds,
      'milestone100Diamonds': milestone100Diamonds,
    };
  }
}
