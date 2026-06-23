import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ai_service.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

/// App-wide service singletons. Initialised once in main() after Firebase is up.
late final FirestoreService db;
late final AuthService auth;
late final AiService ai;

void initServices() {
  final firestore = FirebaseFirestore.instance;
  // On-device cache: reads are served instantly from cache and synced in the
  // background, so hopping between screens doesn't wait on the network.
  firestore.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  db = FirestoreService(firestore);
  auth = AuthService(FirebaseAuth.instance, db);
  ai = AiService(FirebaseFunctions.instanceFor(region: 'us-central1'));
}
