import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// How the app talks to data.
///
/// * [firebase]     – Firebase initialised; all reads/writes go to Firestore.
/// * [demo]         – Explicit development/demo mode. In-memory sample data,
///                    nothing is persisted. Always shown with a banner.
/// * [unconfigured] – Firebase could not be initialised and demo mode was not
///                    requested. The app shows setup instructions.
enum BackendMode { firebase, demo, unconfigured }

class AppConfig {
  AppConfig._();

  /// `--dart-define=DEMO_MODE=true` starts the app in demo mode.
  static const bool demoModeRequested = bool.fromEnvironment('DEMO_MODE');

  /// Demo mode may also be entered from the setup screen, but only in debug
  /// builds, so a misconfigured production build never shows sample data.
  static bool get demoModeAllowed => demoModeRequested || kDebugMode;

  /// Firebase options supplied at build time, e.g.
  /// `flutter run --dart-define-from-file=firebase.env.json`.
  ///
  /// Returns null when the values were not provided. No credentials are
  /// embedded in source. Running `flutterfire configure` and passing
  /// `DefaultFirebaseOptions.currentPlatform` instead is equally valid.
  static FirebaseOptions? get dartDefineFirebaseOptions {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      authDomain: authDomain.isEmpty ? null : authDomain,
    );
  }

  /// Cloud Functions region; must match `functions/index.js`.
  static const String functionsRegion = String.fromEnvironment(
    'FUNCTIONS_REGION',
    defaultValue: 'asia-south1',
  );
}

/// Initialises Firebase if possible and returns the resulting mode.
Future<({BackendMode mode, String? error})> resolveBackendMode() async {
  if (AppConfig.demoModeRequested) return (mode: BackendMode.demo, error: null);
  try {
    final options = AppConfig.dartDefineFirebaseOptions;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      // Native config files (google-services.json / GoogleService-Info.plist)
      // allow initialisation without explicit options.
      await Firebase.initializeApp();
    } else {
      return (
        mode: BackendMode.unconfigured,
        error: 'No Firebase options were provided for this platform.',
      );
    }
    return (mode: BackendMode.firebase, error: null);
  } catch (e) {
    return (mode: BackendMode.unconfigured, error: e.toString());
  }
}
