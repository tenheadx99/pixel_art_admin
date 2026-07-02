import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/schema/ads_config.dart';
import '../core/schema/announcement_config.dart';
import '../core/schema/app_version_config.dart';
import '../core/schema/economy_config.dart';
import '../core/schema/firestore_paths.dart';

/// Typed CRUD for the per-flavor config docs. All writes stamp `updatedAt`.
class ConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<AdsConfig> loadAds(String flavorId) async {
    final snap = await _db.doc(FirestorePaths.adsConfigDoc(flavorId)).get();
    return AdsConfig.fromMap(snap.data() ?? const {});
  }

  Future<void> saveAds(String flavorId, AdsConfig config) {
    return _db.doc(FirestorePaths.adsConfigDoc(flavorId)).set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppVersionConfig> loadApp(String flavorId) async {
    final snap = await _db.doc(FirestorePaths.appConfigDoc(flavorId)).get();
    return AppVersionConfig.fromMap(snap.data() ?? const {});
  }

  Future<void> saveApp(String flavorId, AppVersionConfig config) {
    return _db.doc(FirestorePaths.appConfigDoc(flavorId)).set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<EconomyConfig> loadEconomy(String flavorId) async {
    final snap =
        await _db.doc(FirestorePaths.economyConfigDoc(flavorId)).get();
    return EconomyConfig.fromMap(snap.data() ?? const {});
  }

  Future<void> saveEconomy(String flavorId, EconomyConfig config) {
    return _db.doc(FirestorePaths.economyConfigDoc(flavorId)).set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AnnouncementConfig> loadAnnouncement(String flavorId) async {
    final snap = await _db
        .doc('${FirestorePaths.flavorDoc(flavorId)}/config/announcement')
        .get();
    return AnnouncementConfig.fromMap(snap.data() ?? const {});
  }

  /// Saves the announcement with a fresh stamp so previously dismissed
  /// banners re-appear in the app.
  Future<void> saveAnnouncement(String flavorId, AnnouncementConfig config) {
    return _db
        .doc('${FirestorePaths.flavorDoc(flavorId)}/config/announcement')
        .set({
      ...config.toMap(),
      'stamp': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Raw updatedAt timestamps for the dashboard summary.
  Future<Map<String, DateTime?>> lastUpdated(String flavorId) async {
    Future<DateTime?> ts(String path) async {
      final snap = await _db.doc(path).get();
      final v = snap.data()?['updatedAt'];
      return v is Timestamp ? v.toDate() : null;
    }

    return {
      'ads': await ts(FirestorePaths.adsConfigDoc(flavorId)),
      'app': await ts(FirestorePaths.appConfigDoc(flavorId)),
      'economy': await ts(FirestorePaths.economyConfigDoc(flavorId)),
    };
  }
}
