import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/schema/firestore_paths.dart';

/// Email/password sign-in plus the allowlist check. Being authenticated is
/// not enough — the uid must have a doc in `pixel_art_admins` (the same
/// condition the Firestore rules enforce server-side).
class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  User? get user => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// True when the signed-in uid is on the admin allowlist.
  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc =
        await _db.collection(FirestorePaths.admins).doc(uid).get();
    return doc.exists;
  }
}
