import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'main.dart'; // Import your main file to access StorageService

class FirebaseConfigService {
  static Future<bool> saveAndInitializeFirebase(File jsonFile) async {
    try {
      // Read the JSON file
      final jsonString = await jsonFile.readAsString();
      final config = json.decode(jsonString);

      // Extract Firebase configuration
      final client = config['client'][0];
      final apiKey = client['api_key'][0]['current_key'];
      final appId = config['client_info']['mobilesdk_app_id'];
      final projectId = config['project_info']['project_id'];
      final senderId = config['project_info']['project_number'];

      final firebaseConfig = {
        'apiKey': apiKey,
        'appId': appId,
        'projectId': projectId,
        'senderId': senderId,
      };

      // Save to shared preferences
      await StorageService.setFirebaseConfig(json.encode(firebaseConfig));

      // Reinitialize Firebase
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      );

      return true;
    } catch (e) {
      print('Error saving Firebase config: $e');
      return false;
    }
  }

  static Future<void> reinitializeFromStorage() async {
    final config = await StorageService.getFirebaseConfig();
    if (config != null) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config['apiKey'],
          appId: config['appId'],
          messagingSenderId: config['senderId'],
          projectId: config['projectId'],
        ),
      );
    }
  }
}