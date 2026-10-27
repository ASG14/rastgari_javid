import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const int port = 8081;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$port';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android Emulator -> Windows host
        return 'http://10.0.2.2:$port';

      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:$port';
    }
  }
}
