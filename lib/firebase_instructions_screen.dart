import 'package:flutter/material.dart';

class FirebaseInstructionsScreen extends StatelessWidget {
  final String language;

  const FirebaseInstructionsScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Setup Instructions'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStep(
              'Step 1: Create Firebase Project',
              '1. Go to https://console.firebase.google.com\n'
                  '2. Click "Add project"\n'
                  '3. Enter your store name (e.g., "My Kirana Store")\n'
                  '4. Follow the setup wizard\n'
                  '5. Disable Google Analytics (not needed)',
            ),

            const SizedBox(height: 20),
            _buildStep(
              'Step 2: Add Android App',
              '1. In your Firebase project, click "Add app" → Android\n'
                  '2. Android package name: com.example.upi_payment_helper_with_shop_assistance\n'
                  '3. App nickname: Your Store Name\n'
                  '4. SHA-1: Skip this (optional)\n'
                  '5. Click "Register app"',
            ),

            const SizedBox(height: 20),
            _buildStep(
              'Step 3: Download Config File',
              '1. Click "Download google-services.json"\n'
                  '2. Save the file to your phone downloads\n'
                  '3. Remember where you saved it',
            ),

            const SizedBox(height: 20),
            _buildStep(
              'Step 4: Upload to App',
              '1. Go back to this app\n'
                  '2. Tap "Firebase Setup"\n'
                  '3. Tap "Upload google-services.json"\n'
                  '4. Select the file you downloaded\n'
                  '5. Wait for success message',
            ),

            const SizedBox(height: 20),
            _buildStep(
              '⚠️ IMPORTANT: Security Rules Setup',
              'After uploading, you MUST set up security rules:\n\n'
                  '1. Go back to Firebase Console\n'
                  '2. Click "Firestore Database" in left menu\n'
                  '3. Go to "Rules" tab\n'
                  '4. Replace existing rules with:',
              isImportant: true,
            ),

            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'rules_version = \'2\';\n'
                    'service cloud.firestore {\n'
                    '  match /databases/{database}/documents {\n'
                    '    match /{document=**} {\n'
                    '      allow read, write: if true;\n'
                    '    }\n'
                    '  }\n'
                    '}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              '5. Click "Publish" to save rules\n'
                  '6. Your sync will now work!',
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 30),
            _buildInfoCard(),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Open Firebase Console in browser
                  // You'll need the url_launcher package for this
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Open Firebase Console',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String title, String content, {bool isImportant = false}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isImportant ? Colors.red : Colors.green[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Why This Setup?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '• Your data stays private to your store\n'
                '• You control your own cloud storage\n'
                '• Multiple devices can sync data\n'
                '• No monthly fees (within free limits)\n'
                '• You own your business data completely',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}