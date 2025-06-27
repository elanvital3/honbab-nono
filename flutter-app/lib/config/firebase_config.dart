import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      if (kDebugMode) {
        print('🔥 Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase initialization error: $e');
      }
      rethrow;
    }
  }
}