import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/pixel_art.dart';
import '../core/schema/artwork_override.dart';
import '../core/schema/firestore_paths.dart';
import '../core/schema/remote_artwork.dart';

/// One entry in the merged catalog view: either a bundled artwork (from the
/// seeded bundled_index, possibly with an override applied) or a remote one.
class CatalogEntry {
  final PixelArt art;
  final bool isBundled;
  final int manifestIndex;
  final RemoteArtwork? remote;
  final ArtworkOverride? override;

  const CatalogEntry({
    required this.art,
    required this.isBundled,
    this.manifestIndex = 0,
    this.remote,
    this.override,
  });

  bool get hidden => isBundled ? (override?.hidden ?? false) : !remote!.visible;

  bool get isPremium =>
      isBundled ? (override?.isPremium ?? art.isPremium) : art.isPremium;

  String get category =>
      isBundled ? (override?.category ?? art.category) : art.category;

  int get sortOrder =>
      isBundled ? (override?.sortOrder ?? manifestIndex) : remote!.sortOrder;
}

/// All catalog mutations go through here: every write is a batch that also
/// bumps the flavor's `catalogVersion`, so clients know to refetch. Screens
/// must never write these collections directly.
class CatalogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<CatalogEntry>> loadCatalog(String flavorId) async {
    final bundledSnap =
        await _db.collection(FirestorePaths.bundledIndexCol(flavorId)).get();
    final remoteSnap =
        await _db.collection(FirestorePaths.artworksCol(flavorId)).get();
    final overridesSnap =
        await _db.collection(FirestorePaths.overridesCol(flavorId)).get();

    final overrides = {
      for (final d in overridesSnap.docs)
        d.id: ArtworkOverride.fromMap(d.id, d.data()),
    };

    final entries = <CatalogEntry>[
      for (final d in bundledSnap.docs)
        CatalogEntry(
          art: PixelArt.fromJson(d.data()),
          isBundled: true,
          manifestIndex: (d.data()['manifestIndex'] as num?)?.toInt() ?? 0,
          override: overrides[d.id],
        ),
      for (final d in remoteSnap.docs)
        CatalogEntry(
          art: RemoteArtwork.fromMap(d.data()).art,
          isBundled: false,
          remote: RemoteArtwork.fromMap(d.data()),
        ),
    ];

    entries.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return entries;
  }

  /// Publish a new remote artwork. The id must carry the `rmt_` prefix —
  /// enforced here so it can't be bypassed from any screen.
  Future<void> publishArtwork(String flavorId, RemoteArtwork artwork) {
    final id = artwork.art.id;
    if (!RemoteArtwork.hasRemoteId(id)) {
      throw ArgumentError(
        'Remote artwork id must start with '
        '"${FirestorePaths.remoteArtIdPrefix}": $id',
      );
    }
    final batch = _db.batch();
    batch.set(
      _db.collection(FirestorePaths.artworksCol(flavorId)).doc(id),
      {
        ...artwork.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    _bumpVersion(batch, flavorId);
    return batch.commit();
  }

  /// Update metadata of an existing remote artwork.
  Future<void> updateRemote(
    String flavorId,
    String artId,
    Map<String, dynamic> fields,
  ) {
    final batch = _db.batch();
    batch.update(
      _db.collection(FirestorePaths.artworksCol(flavorId)).doc(artId),
      {...fields, 'updatedAt': FieldValue.serverTimestamp()},
    );
    _bumpVersion(batch, flavorId);
    return batch.commit();
  }

  Future<void> deleteRemote(String flavorId, String artId) {
    final batch = _db.batch();
    batch.delete(
      _db.collection(FirestorePaths.artworksCol(flavorId)).doc(artId),
    );
    _bumpVersion(batch, flavorId);
    return batch.commit();
  }

  /// Write (or clear, when empty) a sparse override for a bundled artwork.
  Future<void> saveOverride(String flavorId, ArtworkOverride override) {
    final ref = _db
        .collection(FirestorePaths.overridesCol(flavorId))
        .doc(override.artId);
    final batch = _db.batch();
    if (override.isEmpty) {
      batch.delete(ref);
    } else {
      batch.set(ref, {
        ...override.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _bumpVersion(batch, flavorId);
    return batch.commit();
  }

  /// Persists a full manual ordering: every entry gets sortOrder = its list
  /// index (override docs for bundled art, field update for remote art), in
  /// one batch with a single version bump.
  Future<void> saveOrder(String flavorId, List<CatalogEntry> ordered) {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      final entry = ordered[i];
      if (entry.isBundled) {
        batch.set(
          _db
              .collection(FirestorePaths.overridesCol(flavorId))
              .doc(entry.art.id),
          {'sortOrder': i, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      } else {
        batch.update(
          _db.collection(FirestorePaths.artworksCol(flavorId)).doc(entry.art.id),
          {'sortOrder': i, 'updatedAt': FieldValue.serverTimestamp()},
        );
      }
    }
    _bumpVersion(batch, flavorId);
    return batch.commit();
  }

  /// Per-art completion counters reported anonymously by the apps
  /// (`stats/{artId}.completions`).
  Future<Map<String, int>> loadStats(String flavorId) async {
    final snap = await _db
        .collection('${FirestorePaths.flavorDoc(flavorId)}/stats')
        .get();
    return {
      for (final d in snap.docs)
        d.id: (d.data()['completions'] as num?)?.toInt() ?? 0,
    };
  }

  // --- Daily Pixel schedule (`daily_schedule/{yyyy-MM-dd}` → {artId}) ---

  CollectionReference<Map<String, dynamic>> _scheduleCol(String flavorId) =>
      _db.collection('${FirestorePaths.flavorDoc(flavorId)}/daily_schedule');

  /// Upcoming (today onwards) scheduled daily picks, date-sorted.
  Future<Map<String, String>> loadSchedule(String flavorId) async {
    final today = dateKey(DateTime.now());
    final snap = await _scheduleCol(flavorId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: today)
        .get();
    final entries = {
      for (final d in snap.docs) d.id: d.data()['artId'] as String? ?? '',
    };
    return Map.fromEntries(
      entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Future<void> saveScheduleEntry(String flavorId, String date, String artId) {
    // No version bump: the app reads today's schedule doc directly each launch.
    return _scheduleCol(flavorId).doc(date).set({
      'artId': artId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteScheduleEntry(String flavorId, String date) {
    return _scheduleCol(flavorId).doc(date).delete();
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _bumpVersion(WriteBatch batch, String flavorId) {
    batch.set(
      _db.doc(FirestorePaths.flavorDoc(flavorId)),
      {
        FlavorDocFields.catalogVersion: FieldValue.increment(1),
        FlavorDocFields.updatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
