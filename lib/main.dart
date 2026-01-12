import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'firebase_service.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_config_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'firebase_instructions_screen.dart';


// ==== REPLACE YOUR CURRENT main() FUNCTION WITH THIS ====
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Try to initialize with custom Firebase config first
    await FirebaseConfigService.reinitializeFromStorage();
  }
  catch (e) {
    // If custom config fails, try default Firebase
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Both Firebase initializations failed: $e');
    }
  }

  runApp(const MyApp());
}
// ==== END OF MAIN FUNCTION ====

// Text-to-Speech Service
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  String _currentLanguage = 'en';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      print('TTS Initialization error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('TTS Stop error: $e');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    try {
      _currentLanguage = languageCode;
      switch (languageCode) {
        case 'hi':
          await _flutterTts.setLanguage("hi-IN");
          break;
        case 'kn':
          await _flutterTts.setLanguage("kn-IN");
          break;
        default:
          await _flutterTts.setLanguage("en-US");
      }
      print('TTS Language set to: $languageCode');
    } catch (e) {
      print('TTS Language error: $e');
      // Fallback to English if the requested language is not available
      await _flutterTts.setLanguage("en-US");
    }
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _flutterTts.setSpeechRate(speed);
    } catch (e) {
      print('TTS Speed error: $e');
    }
  }

  String getCurrentLanguage() {
    return _currentLanguage;
  }
}

// Storage Service Class
class StorageService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _languageKey = 'language';
  static const String _upiIdKey = 'upiId';
  static const String _isSetupCompletedKey = 'isSetupCompleted';
  static const String _transactionsKey = 'transactions';
  static const String _lastSyncKey = 'lastSync';

  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_isLoggedInKey, value);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await _prefs;
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> setLanguage(String languageCode) async {
    final prefs = await _prefs;
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString(_languageKey) ?? 'en';
  }

  static Future<void> setUpiId(String upiId) async {
    final prefs = await _prefs;
    await prefs.setString(_upiIdKey, upiId);
  }

  static Future<String> getUpiId() async {
    final prefs = await _prefs;
    return prefs.getString(_upiIdKey) ?? '';
  }

  static Future<void> setSetupCompleted(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_isSetupCompletedKey, value);
  }

  static Future<bool> isSetupCompleted() async {
    final prefs = await _prefs;
    return prefs.getBool(_isSetupCompletedKey) ?? false;
  }

  // Transaction Management
  static Future<void> addTransaction(Map<String, dynamic> transaction) async {
    final prefs = await _prefs;
    final transactions = await getTransactions();
    transactions.add(transaction);
    await prefs.setString(_transactionsKey, _encodeTransactions(transactions));
    await _updateLastSync();
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await _prefs;
    final transactionsJson = prefs.getString(_transactionsKey);
    if (transactionsJson == null || transactionsJson.isEmpty) return [];
    return _decodeTransactions(transactionsJson);
  }

  static Future<List<Map<String, dynamic>>> getTodayTransactions() async {
    final allTransactions = await getTransactions();
    final today = DateTime.now();
    return allTransactions.where((transaction) {
      final transactionDate = DateTime.parse(transaction['timestamp']);
      return transactionDate.year == today.year &&
          transactionDate.month == today.month &&
          transactionDate.day == today.day;
    }).toList();
  }

  static Future<double> getTodaySales() async {
    final todayTransactions = await getTodayTransactions();
    double total = 0;
    for (var transaction in todayTransactions) {
      total += (transaction['amount'] ?? 0).toDouble();
    }
    return total;
  }

  static Future<void> _updateLastSync() async {
    final prefs = await _prefs;
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> getLastSync() async {
    final prefs = await _prefs;
    final lastSync = prefs.getString(_lastSyncKey);
    return lastSync != null ? DateTime.parse(lastSync) : null;
  }

  // In StorageService class, replace these methods:

  static String _encodeTransactions(List<Map<String, dynamic>> transactions) {
    final List<Map<String, dynamic>> simplified = transactions.map((t) {
      return {
        'timestamp': t['timestamp'],
        'amount': t['amount'],
        'type': t['type'] ?? 'payment_received',
        'status': t['status'] ?? 'successful',
      };
    }).toList();

    return json.encode(simplified);
  }

  static List<Map<String, dynamic>> _decodeTransactions(String encoded) {
    if (encoded.isEmpty) return [];
    try {
      final List<dynamic> decoded = json.decode(encoded);
      return decoded.map((item) {
        return {
          'timestamp': item['timestamp'],
          'amount': item['amount'] is int ? (item['amount'] as int).toDouble() : item['amount'],
          'type': item['type'] ?? 'payment_received',
          'status': item['status'] ?? 'successful',
        };
      }).toList();
    } catch (e) {
      print('Error decoding transactions: $e');
      return [];
    }
  }

  static Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.remove(_isLoggedInKey);
    // Keep UPI ID and transactions for convenience
  }
  static const String _firebaseConfigKey = 'firebaseConfig';

  static Future<void> setFirebaseConfig(String configJson) async {
    final prefs = await _prefs;
    await prefs.setString(_firebaseConfigKey, configJson);
  }

  static Future<Map<String, dynamic>?> getFirebaseConfig() async {
    final prefs = await _prefs;
    final configJson = prefs.getString(_firebaseConfigKey);
    if (configJson != null) {
      return json.decode(configJson);
    }
    return null;
  }

  static Future<void> clearFirebaseConfig() async {
    final prefs = await _prefs;
    await prefs.remove(_firebaseConfigKey);
  }

}

// Language Service Class
class LanguageService {
  static Map<String, Map<String, String>> translations = {
    'en': {
      'setup_upi': 'Setup Your UPI Account',
      'enter_upi_details': 'Enter your UPI ID to get started',
      'upi_id': 'UPI ID',
      'upi_hint': 'example@ybl or example@paytm',
      'save_continue': 'Save & Continue',
      'setup_complete': 'Setup Complete!',
      'setup_success': 'Your UPI account has been setup successfully. You can now start using the app.',
      'get_started': 'Get Started',
      'enter_upi': 'Please enter your UPI ID',
      'valid_upi': 'Enter a valid UPI ID (e.g., example@ybl)',
      'dashboard': 'Dashboard',
      'welcome': 'Welcome',
      'language': 'Language',
      'quick_actions': 'Quick Actions',
      'logout': 'Logout',
      'logout_confirmation': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'receive_payment': 'Receive Payment',
      'today_sales': 'Today Sales',
      'transaction_history': 'Transaction History',
      'voice_help': 'Voice Help',
      'voice_settings': 'Voice Settings',
      'show_qr': 'Show QR Code',
      'payment_received': 'Payment Received',
      'share_upi': 'Share your UPI ID with customer',
      'scan_qr': 'Scan QR Code to Pay',
      'total_sales': 'Total Sales',
      'transactions': 'Transactions',
      'amount': 'Amount',
      'time': 'Time',
      'status': 'Status',
      'successful': 'Successful',
      'date': 'Date',
      'cashbook': 'Daily Cashbook',
      'sync_status': 'Sync Status',
      'last_sync': 'Last Sync',
      'synced': 'Synced',
      'pending': 'Pending',
      'change_language': 'Change Language',
      'select_language': 'Select Your Language',
    },
    'hi': {
      'setup_upi': 'अपना UPI अकाउंट सेटअप करें',
      'enter_upi_details': 'शुरू करने के लिए अपना UPI ID दर्ज करें',
      'upi_id': 'UPI ID',
      'upi_hint': 'example@ybl या example@paytm',
      'save_continue': 'सहेजें और जारी रखें',
      'setup_complete': 'सेटअप पूरा हुआ!',
      'setup_success': 'आपका UPI अकाउंट सफलतापूर्वक सेटअप हो गया है। अब आप ऐप का उपयोग कर सकते हैं।',
      'get_started': 'शुरू करें',
      'enter_upi': 'कृपया अपना UPI ID दर्ज करें',
      'valid_upi': 'एक वैध UPI ID दर्ज करें (जैसे, example@ybl)',
      'dashboard': 'डैशबोर्ड',
      'welcome': 'स्वागत है',
      'language': 'भाषा',
      'quick_actions': 'त्वरित कार्य',
      'logout': 'लॉगआउट',
      'logout_confirmation': 'क्या आप वाकई लॉगआउट करना चाहते हैं?',
      'cancel': 'रद्द करें',
      'receive_payment': 'भुगतान प्राप्त करें',
      'today_sales': 'आज की बिक्री',
      'transaction_history': 'लेन-देन इतिहास',
      'voice_help': 'वॉयस सहायता',
      'voice_settings': 'वॉयस सेटिंग्स',
      'show_qr': 'QR कोड दिखाएं',
      'payment_received': 'भुगतान प्राप्त हुआ',
      'share_upi': 'ग्राहक को अपना UPI ID शेयर करें',
      'scan_qr': 'भुगतान करने के लिए QR कोड स्कैन करें',
      'total_sales': 'कुल बिक्री',
      'transactions': 'लेन-देन',
      'amount': 'राशि',
      'time': 'समय',
      'status': 'स्थिति',
      'successful': 'सफल',
      'date': 'तारीख',
      'cashbook': 'दैनिक कैशबुक',
      'sync_status': 'सिंक स्थिति',
      'last_sync': 'अंतिम सिंक',
      'synced': 'सिंक हुआ',
      'pending': 'लंबित',
      'change_language': 'भाषा बदलें',
      'select_language': 'अपनी भाषा चुनें',
    },
    'kn': {
      'setup_upi': 'ನಿಮ್ಮ UPI ಖಾತೆಯನ್ನು ಸೆಟಪ್ ಮಾಡಿ',
      'enter_upi_details': 'ಪ್ರಾರಂಭಿಸಲು ನಿಮ್ಮ UPI ID ನಮೂದಿಸಿ',
      'upi_id': 'UPI ID',
      'upi_hint': 'example@ybl ಅಥವಾ example@paytm',
      'save_continue': 'ಉಳಿಸಿ ಮತ್ತು ಮುಂದುವರಿಸಿ',
      'setup_complete': 'ಸೆಟಪ್ ಪೂರ್ಣಗೊಂಡಿದೆ!',
      'setup_success': 'ನಿಮ್ಮ UPI ಖಾತೆಯನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸೆಟಪ್ ಮಾಡಲಾಗಿದೆ. ಈಗ ನೀವು ಅಪ್ಲಿಕೇಶನ್ ಬಳಸಲು ಪ್ರಾರಂಭಿಸಬಹುದು.',
      'get_started': 'ಪ್ರಾರಂಭಿಸಿ',
      'enter_upi': 'ದಯವಿಟ್ಟು ನಿಮ್ಮ UPI ID ನಮೂದಿಸಿ',
      'valid_upi': 'ಮಾನ್ಯ UPI ID ನಮೂದಿಸಿ (ಉದಾ., example@ybl)',
      'dashboard': 'ಡ್ಯಾಶ್ಬೋರ್ಡ್',
      'welcome': 'ಸ್ವಾಗತ',
      'language': 'ಭಾಷೆ',
      'quick_actions': 'ತ್ವರಿತ ಕ್ರಿಯೆಗಳು',
      'logout': 'ಲಾಗ್ ಔಟ್',
      'logout_confirmation': 'ನೀವು ಖಚಿತವಾಗಿ ಲಾಗ್ ಔಟ್ ಮಾಡಲು ಬಯಸುವಿರಾ?',
      'cancel': 'ರದ್ದುಮಾಡಿ',
      'receive_payment': 'ಪಾವತಿ ಸ್ವೀಕರಿಸಿ',
      'today_sales': 'ಇಂದಿನ ಮಾರಾಟ',
      'transaction_history': 'ವಹಿವಾಟು ಇತಿಹಾಸ',
      'voice_help': 'ಧ್ವನಿ ಸಹಾಯ',
      'voice_settings': 'ಧ್ವನಿ ಸೆಟ್ಟಿಂಗ್ಗಳು',
      'show_qr': 'QR ಕೋಡ್ ತೋರಿಸಿ',
      'payment_received': 'ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ',
      'share_upi': 'ಗ್ರಾಹಕರಿಗೆ ನಿಮ್ಮ UPI ID ಹಂಚಿಕೊಳ್ಳಿ',
      'scan_qr': 'ಪಾವತಿಸಲು QR ಕೋಡ್ ಸ್ಕ್ಯಾನ್ ಮಾಡಿ',
      'total_sales': 'ಒಟ್ಟು ಮಾರಾಟ',
      'transactions': 'ವಹಿವಾಟುಗಳು',
      'amount': 'ಮೊತ್ತ',
      'time': 'ಸಮಯ',
      'status': 'ಸ್ಥಿತಿ',
      'successful': 'ಯಶಸ್ವಿ',
      'date': 'ದಿನಾಂಕ',
      'cashbook': 'ದೈನಂದಿನ ಕ್ಯಾಶ್‌ಬುಕ್',
      'sync_status': 'ಸಿಂಕ್ ಸ್ಥಿತಿ',
      'last_sync': 'ಕೊನೆಯ ಸಿಂಕ್',
      'synced': 'ಸಿಂಕ್ ಆಗಿದೆ',
      'pending': 'ಬಾಕಿ',
      'change_language': 'ಭಾಷೆ ಬದಲಾಯಿಸಿ',
      'select_language': 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ',
    },
  };

  static String getText(String languageCode, String key) {
    return translations[languageCode]?[key] ?? translations['en']![key]!;
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rural UPI Assistant',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
      ),
      home: FutureBuilder(
        future: StorageService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          final isLoggedIn = snapshot.data ?? false;

          if (isLoggedIn) {
            return FutureBuilder(
              future: StorageService.getLanguage(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }
                final language = snapshot.data ?? 'en';
                return MainDashboard(language: language);
              },
            );
          } else {
            return const WelcomeScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[600],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.store,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              'Rural UPI Assistant',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? selectedLanguage;

  final List<Map<String, String>> languages = [
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'en', 'name': 'English'},
    {'code': 'kn', 'name': 'ಕನ್ನಡ'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.store,
                        size: 60,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Rural UPI Assistant',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Digital Shop Partner',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    'Choose Your Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: languages.map((lang) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LanguageButton(
                          languageName: lang['name']!,
                          isSelected: selectedLanguage == lang['code'],
                          onTap: () {
                            setState(() {
                              selectedLanguage = lang['code'];
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: selectedLanguage != null ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UpiSetupScreen(selectedLanguage: selectedLanguage!),
                          ),
                        );
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Continue →',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageButton extends StatelessWidget {
  final String languageName;
  final bool isSelected;
  final VoidCallback onTap;

  const LanguageButton({
    super.key,
    required this.languageName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.grey[50],
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            languageName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.green[800] : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

class UpiSetupScreen extends StatefulWidget {
  final String selectedLanguage;

  const UpiSetupScreen({super.key, required this.selectedLanguage});

  @override
  _UpiSetupScreenState createState() => _UpiSetupScreenState();
}

class _UpiSetupScreenState extends State<UpiSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.getText(widget.selectedLanguage, 'setup_upi')),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                LanguageService.getText(widget.selectedLanguage, 'setup_upi'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LanguageService.getText(widget.selectedLanguage, 'enter_upi_details'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // UPI ID Field
              Text(
                LanguageService.getText(widget.selectedLanguage, 'upi_id'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _upiIdController,
                decoration: InputDecoration(
                  hintText: LanguageService.getText(widget.selectedLanguage, 'upi_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.payment),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return LanguageService.getText(widget.selectedLanguage, 'enter_upi');
                  }
                  // Simple UPI validation - just check if it contains @ symbol
                  if (!value.contains('@')) {
                    return LanguageService.getText(widget.selectedLanguage, 'valid_upi');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveUPIDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    LanguageService.getText(widget.selectedLanguage, 'save_continue'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _saveUPIDetails() async {
    if (_formKey.currentState!.validate()) {
      await StorageService.setLoggedIn(true);
      await StorageService.setLanguage(widget.selectedLanguage);
      await StorageService.setUpiId(_upiIdController.text.trim());
      await StorageService.setSetupCompleted(true);

      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(LanguageService.getText(widget.selectedLanguage, 'setup_complete')),
          content: Text(LanguageService.getText(widget.selectedLanguage, 'setup_success')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainDashboard(language: widget.selectedLanguage),
                  ),
                );
              },
              child: Text(LanguageService.getText(widget.selectedLanguage, 'get_started')),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    super.dispose();
  }
}

class MainDashboard extends StatefulWidget {
  final String language;

  const MainDashboard({super.key, required this.language});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }
// ==== ADD THIS METHOD IN _MainDashboardState CLASS ====
  void _showFirebaseConfigScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FirebaseConfigScreen(language: widget.language),
      ),
    );
  }
// ==== END OF METHOD ====
  void _initializeVoice() async {
    await VoiceService().init();
    await VoiceService().setLanguage(widget.language);
    Future.delayed(const Duration(seconds: 1), () {
      _playVoiceConfirmation(_getLocalizedWelcomeMessage());
    });
  }

  String _getLocalizedWelcomeMessage() {
    switch (widget.language) {
      case 'hi':
        return 'आपकी दुकान में आपका स्वागत है! भुगतान स्वीकार करने के लिए तैयार हैं।';
      case 'kn':
        return 'ನಿಮ್ಮ ಅಂಗಡಿಗೆ ಸುಸ್ವಾಗತ! ಪಾವತಿಗಳನ್ನು ಸ್ವೀಕರಿಸಲು ಸಿದ್ಧವಾಗಿದೆ.';
      default:
        return 'Welcome to your shop! Ready to accept payments.';
    }
  }

  // UPI URL Generator with optional amount
  String _generateUpiUrl(String upiId, {double? amount}) {
    String baseUrl = "upi://pay?pa=$upiId&pn=Shop&cu=INR";
    if (amount != null) {
      String formattedAmount = amount.toStringAsFixed(2);
      return "$baseUrl&am=$formattedAmount";
    }
    return baseUrl;
  }

  // Payment Options Selection
  void _showPaymentOptions(BuildContext context) {
    _playVoiceConfirmation(_getLocalizedPaymentTypeMessage());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getLocalizedText('choose_payment_type')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Static QR Option
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.green),
              title: Text(_getLocalizedText('static_qr')),
              subtitle: Text(_getLocalizedText('static_qr_desc')),
              onTap: () {
                Navigator.pop(context);
                _showStaticQRCode(context);
              },
            ),
            const Divider(),
            // Dynamic QR Option
            ListTile(
              leading: const Icon(Icons.qr_code_2, color: Colors.blue),
              title: Text(_getLocalizedText('dynamic_qr')),
              subtitle: Text(_getLocalizedText('dynamic_qr_desc')),
              onTap: () {
                Navigator.pop(context);
                _showAmountInputDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _playVoiceConfirmation(_getLocalizedText('cancelled'));
            },
            child: Text(LanguageService.getText(widget.language, 'cancel')),
          ),
        ],
      ),
    );
  }

  String _getLocalizedText(String key, [double? amount]) {
    switch (key) {
      case 'choose_payment_type':
        switch (widget.language) {
          case 'hi': return 'भुगतान प्रकार चुनें';
          case 'kn': return 'ಪಾವತಿ ಪ್ರಕಾರವನ್ನು ಆಯ್ಕೆಮಾಡಿ';
          default: return 'Choose Payment Type';
        }
      case 'static_qr':
        switch (widget.language) {
          case 'hi': return 'स्थिर QR कोड';
          case 'kn': return 'ಸ್ಥಿರ QR ಕೋಡ್';
          default: return 'Static QR Code';
        }
      case 'static_qr_desc':
        switch (widget.language) {
          case 'hi': return 'ग्राहक कोई भी राशि दर्ज कर सकता है';
          case 'kn': return 'ಗ್ರಾಹಕರು ಯಾವುದೇ ಮೊತ್ತವನ್ನು ನಮೂದಿಸಬಹುದು';
          default: return 'Customer enters any amount';
        }
      case 'dynamic_qr':
        switch (widget.language) {
          case 'hi': return 'डायनामिक QR कोड';
          case 'kn': return 'ಡೈನಾಮಿಕ್ QR ಕೋಡ್';
          default: return 'Dynamic QR Code';
        }
      case 'dynamic_qr_desc':
        switch (widget.language) {
          case 'hi': return 'निश्चित राशि का भुगतान';
          case 'kn': return 'ನಿಗದಿತ ಮೊತ್ತದ ಪಾವತಿ';
          default: return 'Fixed amount payment';
        }
      case 'cancelled':
        switch (widget.language) {
          case 'hi': return 'रद्द किया गया';
          case 'kn': return 'ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ';
          default: return 'Cancelled';
        }
      case 'enter_amount':
        switch (widget.language) {
          case 'hi': return 'राशि दर्ज करें';
          case 'kn': return 'ಮೊತ್ತ ನಮೂದಿಸಿ';
          default: return 'Enter Amount';
        }
      case 'amount_rupee':
        switch (widget.language) {
          case 'hi': return 'राशि (₹)';
          case 'kn': return 'ಮೊತ್ತ (₹)';
          default: return 'Amount (₹)';
        }
      case 'generate_qr':
        switch (widget.language) {
          case 'hi': return 'QR कोड जनरेट करें';
          case 'kn': return 'QR ಕೋಡ್ ಉತ್ಪಾದಿಸಿ';
          default: return 'Generate QR';
        }
      case 'payment_received_success':
        switch (widget.language) {
          case 'hi': return 'भुगतान सफलतापूर्वक प्राप्त हुआ! धन्यवाद!';
          case 'kn': return 'ಪಾವತಿ ಯಶಸ್ವಿಯಾಗಿ ಪಡೆಯಲಾಗಿದೆ! ಧನ್ಯವಾದಗಳು!';
          default: return 'Payment received successfully! Thank you!';
        }
      case 'slow_voice':
        switch (widget.language) {
          case 'hi': return 'धीमी आवाज सक्रिय';
          case 'kn': return 'ನಿಧಾನ ಧ್ವನಿ ಸಕ್ರಿಯಗೊಳಿಸಲಾಗಿದೆ';
          default: return 'Slow voice activated';
        }
      case 'normal_voice':
        switch (widget.language) {
          case 'hi': return 'सामान्य आवाज सक्रिय';
          case 'kn': return 'ಸಾಮಾನ್ಯ ಧ್ವನಿ ಸಕ್ರಿಯಗೊಳಿಸಲಾಗಿದೆ';
          default: return 'Normal voice activated';
        }
      case 'fast_voice':
        switch (widget.language) {
          case 'hi': return 'तेज आवाज सक्रिय';
          case 'kn': return 'ವೇಗದ ಧ್ವನಿ ಸಕ್ರಿಯಗೊಳಿಸಲಾಗಿದೆ';
          default: return 'Fast voice activated';
        }
      case 'choose_voice_speed':
        switch (widget.language) {
          case 'hi': return 'आवाज की गति चुनें:';
          case 'kn': return 'ಧ್ವನಿಯ ವೇಗವನ್ನು ಆಯ್ಕೆಮಾಡಿ:';
          default: return 'Choose voice speed:';
        }
      case 'your_upi_id':
        switch (widget.language) {
          case 'hi': return 'आपका UPI ID:';
          case 'kn': return 'ನಿಮ್ಮ UPI ID:';
          default: return 'YOUR UPI ID:';
        }
      case 'any_amount':
        switch (widget.language) {
          case 'hi': return 'कोई भी राशि';
          case 'kn': return 'ಯಾವುದೇ ಮೊತ್ತ';
          default: return 'Any Amount';
        }
      case 'scan_to_pay':
        if (amount != null) {
          switch (widget.language) {
            case 'hi': return '₹$amount का भुगतान करने के लिए स्कैन करें';
            case 'kn': return '₹$amount ಪಾವತಿಸಲು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ';
            default: return 'Scan to pay ₹$amount';
          }
        } else {
          switch (widget.language) {
            case 'hi': return 'भुगतान करने के लिए स्कैन करें';
            case 'kn': return 'ಪಾವತಿಸಲು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ';
            default: return 'Scan to pay';
          }
        }
      case 'amount_to_pay':
        switch (widget.language) {
          case 'hi': return 'भुगतान करने के लिए राशि:';
          case 'kn': return 'ಪಾವತಿಸಬೇಕಾದ ಮೊತ್ತ:';
          default: return 'AMOUNT TO PAY:';
        }
      case 'showing_static_qr':
        switch (widget.language) {
          case 'hi': return 'स्थिर QR कोड दिखाया जा रहा है। ग्राहक कोई भी राशि दे सकता है।';
          case 'kn': return 'ಸ್ಥಿರ QR ಕೋಡ್ ತೋರಿಸಲಾಗುತ್ತಿದೆ. ಗ್ರಾಹಕರು ಯಾವುದೇ ಮೊತ್ತವನ್ನು ಪಾವತಿಸಬಹುದು.';
          default: return 'Showing static QR code. Customer can pay any amount.';
        }
      case 'qr_generated_for':
        if (amount != null) {
          switch (widget.language) {
            case 'hi': return '₹$amount के लिए QR कोड जनरेट किया गया';
            case 'kn': return '₹$amount ಗಾಗಿ QR ಕೋಡ್ ಉತ್ಪಾದಿಸಲಾಗಿದೆ';
            default: return 'QR code generated for ₹$amount';
          }
        } else {
          switch (widget.language) {
            case 'hi': return 'QR कोड जनरेट किया गया';
            case 'kn': return 'QR ಕೋಡ್ ಉತ್ಪಾದಿಸಲಾಗಿದೆ';
            default: return 'QR code generated';
          }
        }
      case 'showing_qr_for_payment':
        switch (widget.language) {
          case 'hi': return 'भुगतान के लिए QR कोड दिखाया जा रहा है।';
          case 'kn': return 'ಪಾವತಿಗಾಗಿ QR ಕೋಡ್ ತೋರಿಸಲಾಗುತ್ತಿದೆ.';
          default: return 'Showing QR code for payment.';
        }
      case 'please_enter_valid_amount':
        switch (widget.language) {
          case 'hi': return 'कृपया वैध राशि दर्ज करें।';
          case 'kn': return 'ದಯವಿಟ್ಟು ಮಾನ್ಯ ಮೊತ್ತವನ್ನು ನಮೂದಿಸಿ.';
          default: return 'Please enter valid amount.';
        }
      case 'opening_payment_options':
        switch (widget.language) {
          case 'hi': return 'भुगतान विकल्प खोले जा रहे हैं।';
          case 'kn': return 'ಪಾವತಿ ಆಯ್ಕೆಗಳನ್ನು ತೆರೆಯಲಾಗುತ್ತಿದೆ.';
          default: return 'Opening payment options.';
        }
      case 'recent_transactions':
        switch (widget.language) {
          case 'hi': return 'हाल के लेन-देन:';
          case 'kn': return 'ಇತ್ತೀಚಿನ ವಹಿವಾಟುಗಳು:';
          default: return 'Recent Transactions:';
        }
      case 'no_transactions':
        switch (widget.language) {
          case 'hi': return 'अभी तक कोई लेन-देन नहीं';
          case 'kn': return 'ಇನ್ನೂ ಯಾವುದೇ ವಹಿವಾಟುಗಳಿಲ್ಲ';
          default: return 'No transactions yet';
        }
      case 'showing_today_sales':
        switch (widget.language) {
          case 'hi': return 'आज की बिक्री सारांश दिखाया जा रहा है।';
          case 'kn': return 'ಇಂದಿನ ಮಾರಾಟ ಸಾರಾಂಶ ತೋರಿಸಲಾಗುತ್ತಿದೆ.';
          default: return 'Showing today sales summary.';
        }
      case 'closing_sales_summary':
        switch (widget.language) {
          case 'hi': return 'बिक्री सारांश बंद किया जा रहा है।';
          case 'kn': return 'ಮಾರಾಟ ಸಾರಾಂಶ ಮುಚ್ಚಲಾಗುತ್ತಿದೆ.';
          default: return 'Closing sales summary.';
        }
      case 'showing_complete_history':
        switch (widget.language) {
          case 'hi': return 'पूरा लेन-देन इतिहास दिखाया जा रहा है।';
          case 'kn': return 'ಪೂರ್ಣ ವಹಿವಾಟು ಇತಿಹಾಸ ತೋರಿಸಲಾಗುತ್ತಿದೆ.';
          default: return 'Showing complete transaction history.';
        }
      case 'showing_sync_status':
        switch (widget.language) {
          case 'hi': return 'सिंक स्थिति दिखाई जा रही है।';
          case 'kn': return 'ಸಿಂಕ್ ಸ್ಥಿತಿ ತೋರಿಸಲಾಗುತ್ತಿದೆ.';
          default: return 'Showing sync status.';
        }
      default:
        return key;
    }
  }

  String _getLocalizedPaymentTypeMessage() {
    switch (widget.language) {
      case 'hi':
        return 'भुगतान प्रकार चुनें। किसी भी राशि के लिए स्थिर QR, निश्चित राशि के लिए डायनामिक QR।';
      case 'kn':
        return 'ಪಾವತಿ ಪ್ರಕಾರವನ್ನು ಆಯ್ಕೆಮಾಡಿ. ಯಾವುದೇ ಮೊತ್ತಕ್ಕೆ ಸ್ಥಿರ QR, ನಿಗದಿತ ಮೊತ್ತಕ್ಕೆ ಡೈನಾಮಿಕ್ QR.';
      default:
        return 'Choose payment type. Static QR for any amount, Dynamic QR for fixed amount.';
    }
  }

  // Amount Input Dialog for Dynamic QR
  void _showAmountInputDialog(BuildContext context) {
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getLocalizedText('enter_amount')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _getLocalizedText('amount_rupee'),
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [10, 20, 50, 100, 200, 500].map((amount) {
                return ElevatedButton(
                  onPressed: () {
                    amountController.text = amount.toString();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green[800],
                  ),
                  child: Text('₹$amount'),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _playVoiceConfirmation(_getLocalizedText('cancelled'));
            },
            child: Text(LanguageService.getText(widget.language, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                double amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  Navigator.pop(context);
                  _showDynamicQRCode(context, amount);
                } else {
                  _playVoiceConfirmation(_getLocalizedText('please_enter_valid_amount'));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(_getLocalizedText('generate_qr'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Static QR Code (Any Amount)
  void _showStaticQRCode(BuildContext context) {
    _playVoiceConfirmation(_getLocalizedText('showing_static_qr'));
    _showQRCode(context);
  }

  // Dynamic QR Code (Fixed Amount)
  void _showDynamicQRCode(BuildContext context, double amount) {
    _playVoiceConfirmation(_getLocalizedText('qr_generated_for').replaceAll('{amount}', '₹$amount'));
    _showQRCodeWithAmount(context, amount);
  }

  String _getLocalizedTextWithAmount(String key, double amount) {
    switch (key) {
      case 'showing_static_qr':
        switch (widget.language) {
          case 'hi': return 'स्थिर QR कोड दिखाया जा रहा है। ग्राहक कोई भी राशि दे सकता है।';
          case 'kn': return 'ಸ್ಥಿರ QR ಕೋಡ್ ತೋರಿಸಲಾಗುತ್ತಿದೆ. ಗ್ರಾಹಕರು ಯಾವುದೇ ಮೊತ್ತವನ್ನು ಪಾವತಿಸಬಹುದು.';
          default: return 'Showing static QR code. Customer can pay any amount.';
        }
      case 'qr_generated_for':
        switch (widget.language) {
          case 'hi': return '{amount} के लिए QR कोड जनरेट किया गया';
          case 'kn': return '{amount} ಗಾಗಿ QR ಕೋಡ್ ಉತ್ಪಾದಿಸಲಾಗಿದೆ';
          default: return 'QR code generated for {amount}';
        }
      case 'showing_qr_for_payment':
        switch (widget.language) {
          case 'hi': return 'भुगतान के लिए QR कोड दिखाया जा रहा है।';
          case 'kn': return 'ಪಾವತಿಗಾಗಿ QR ಕೋಡ್ ತೋರಿಸಲಾಗುತ್ತಿದೆ.';
          default: return 'Showing QR code for payment.';
        }
      case 'please_enter_valid_amount':
        switch (widget.language) {
          case 'hi': return 'कृपया वैध राशि दर्ज करें।';
          case 'kn': return 'ದಯವಿಟ್ಟು ಮಾನ್ಯ ಮೊತ್ತವನ್ನು ನಮೂದಿಸಿ.';
          default: return 'Please enter valid amount.';
        }
      default:
        return key;
    }
  }

  // Static QR Display
  void _showQRCode(BuildContext context) {
    _playVoiceConfirmation(_getLocalizedTextWithAmount('showing_qr_for_payment', 0));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FutureBuilder(
        future: StorageService.getUpiId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Dialog(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading QR Code...'),
                  ],
                ),
              ),
            );
          }

          final upiId = snapshot.data ?? 'not-set@ybl';
          final upiUrl = _generateUpiUrl(upiId);

          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Payment Header
                  const Icon(Icons.payment, size: 50, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    LanguageService.getText(widget.language, 'receive_payment'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // UPI ID Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _getLocalizedText('your_upi_id'),
                          style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          upiId,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          LanguageService.getText(widget.language, 'share_upi'),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: upiUrl,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          LanguageService.getText(widget.language, 'scan_qr'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getLocalizedText('any_amount'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _playVoiceConfirmation(_getLocalizedText('cancelled'));
                          },
                          child: Text(LanguageService.getText(widget.language, 'cancel')),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmPayment(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text(
                            LanguageService.getText(widget.language, 'payment_received'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Dynamic QR Display with Amount
  void _showQRCodeWithAmount(BuildContext context, double amount) {
    _playVoiceConfirmation(_getLocalizedTextWithAmount('qr_generated_for', amount).replaceAll('{amount}', '₹$amount'));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FutureBuilder(
        future: StorageService.getUpiId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Loading QR Code...'),
                  ],
                ),
              ),
            );
          }

          final upiId = snapshot.data ?? 'not-set@ybl';
          final upiUrl = _generateUpiUrl(upiId, amount: amount);

          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amount Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _getLocalizedText('amount_to_pay'),
                          style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹$amount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // QR Code
                  QrImageView(
                    data: upiUrl,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _getLocalizedText('scan_to_pay').replaceAll('{amount}', amount.toString()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _playVoiceConfirmation(_getLocalizedText('cancelled'));
                          },
                          child: Text(LanguageService.getText(widget.language, 'cancel')),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmPaymentWithAmount(context, amount);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text(LanguageService.getText(widget.language, 'payment_received'), style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Payment Confirmation (Static QR)
  void _confirmPayment(BuildContext context) {
    _recordTransaction(0); // 0 amount for static QR
    String message = _getLocalizedText('payment_received_success');
    _playVoiceConfirmation(message);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${LanguageService.getText(widget.language, 'payment_received')}!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Payment Confirmation with Amount (Dynamic QR)
  void _confirmPaymentWithAmount(BuildContext context, double amount) {
    _recordTransaction(amount);
    String message;
    switch (widget.language) {
      case 'hi':
        message = '₹$amount का भुगतान सफलतापूर्वक प्राप्त हुआ! धन्यवाद!';
        break;
      case 'kn':
        message = '₹$amount ಪಾವತಿ ಯಶಸ್ವಿಯಾಗಿ ಪಡೆಯಲಾಗಿದೆ! ಧನ್ಯವಾದಗಳು!';
        break;
      default:
        message = 'Payment of ₹$amount received successfully! Thank you!';
    }

    _playVoiceConfirmation(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${LanguageService.getText(widget.language, 'payment_received')} ₹$amount!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Record transaction to local storage
  void _recordTransaction(double amount) async {
    final transaction = {
      'timestamp': DateTime.now().toIso8601String(),
      'amount': amount,
      'type': 'payment_received',
      'status': 'successful',
    };
    await StorageService.addTransaction(transaction);
  }

  // Updated Payment Flow
  void _startPaymentProcess(BuildContext context) {
    _playVoiceConfirmation(_getLocalizedText('opening_payment_options'));
    _showPaymentOptions(context);
  }

  void _playVoiceConfirmation(String message) async {
    try {
      await VoiceService().speak(message);
    } catch (e) {
      print('Voice error: $e');
    }
  }

  void _playHelpInstructions() {
    final voiceMessage = _getLocalizedHelpInstructions();
    _playVoiceConfirmation(voiceMessage);
  }

  String _getLocalizedHelpInstructions() {
    switch (widget.language) {
      case 'hi':
        return 'रूरल यूपीआई असिस्टेंट में आपका स्वागत है। '
            'भुगतान के लिए हरे बटन को दबाएं। '
            'बिक्री सारांश के लिए बैंगनी बटन दबाएं। '
            'आवाज सहायता के लिए नीले बटन को दबाएं। '
            'आवाज सेटिंग्स के लिए नारंगी बटन दबाएं। '
            'लेन-देन इतिहास के लिए लाल बटन दबाएं। '
            'भाषा बदलने के लिए हरे रंग की भाषा बटन दबाएं।';
      case 'kn':
        return 'ಗ್ರಾಮೀಣ UPI ಸಹಾಯಕಕ್ಕೆ ಸುಸ್ವಾಗತ. '
            'ಪಾವತಿಗಾಗಿ ಹಸಿರು ಬಟನ್ ಒತ್ತಿರಿ. '
            'ಮಾರಾಟ ಸಾರಾಂಶಕ್ಕಾಗಿ ನೇರಳೆ ಬಟನ್ ಒತ್ತಿರಿ. '
            'ಧ್ವನಿ ಸಹಾಯಕ್ಕಾಗಿ ನೀಲಿ ಬಟನ್ ಒತ್ತಿರಿ. '
            'ಧ್ವನಿ ಸೆಟ್ಟಿಂಗ್ಗಳಿಗಾಗಿ ಕಿತ್ತಳೆ ಬಟನ್ ಒತ್ತಿರಿ. '
            'ವಹಿವಾಟು ಇತಿಹಾಸಕ್ಕಾಗಿ ಕೆಂಪು ಬಟನ್ ಒತ್ತಿರಿ. '
            'ಭಾಷೆ ಬದಲಾಯಿಸಲು ಹಸಿರು ಭಾಷಾ ಬಟನ್ ಒತ್ತಿರಿ.';
      default:
        return 'Welcome to Rural UPI Assistant. '
            'Press green button for payment. '
            'Press purple button for sales summary. '
            'Press blue button for voice help. '
            'Press orange button for voice settings. '
            'Press red button for transaction history. '
            'Press green language button to change language.';
    }
  }

  void _voiceSetup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LanguageService.getText(widget.language, 'voice_settings')),
        content: Text(_getLocalizedText('choose_voice_speed')),
        actions: [
          TextButton(
            onPressed: () {
              VoiceService().setSpeed(0.3);
              _playVoiceConfirmation(_getLocalizedText('slow_voice'));
              Navigator.pop(context);
            },
            child: const Text('Slow'),
          ),
          TextButton(
            onPressed: () {
              VoiceService().setSpeed(0.5);
              _playVoiceConfirmation(_getLocalizedText('normal_voice'));
              Navigator.pop(context);
            },
            child: const Text('Normal'),
          ),
          TextButton(
            onPressed: () {
              VoiceService().setSpeed(0.8);
              _playVoiceConfirmation(_getLocalizedText('fast_voice'));
              Navigator.pop(context);
            },
            child: const Text('Fast'),
          ),
        ],
      ),
    );
  }

  void _showTodaySales(BuildContext context) {
    _playVoiceConfirmation(_getLocalizedText('showing_today_sales'));

    showDialog(
      context: context,
      builder: (context) => FutureBuilder(
        future: Future.wait([
          StorageService.getTodaySales(),
          StorageService.getTodayTransactions(),
          StorageService.getLastSync(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AlertDialog(
              title: Text('Loading...'),
              content: CircularProgressIndicator(),
            );
          }

          final todaySales = snapshot.data?[0] ?? 0.0;
          final todayTransactions = snapshot.data?[1] as List<Map<String, dynamic>>? ?? [];
          final lastSync = snapshot.data?[2] as DateTime?;

          return AlertDialog(
            title: Text(LanguageService.getText(widget.language, 'cashbook')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${LanguageService.getText(widget.language, 'total_sales')}: ₹${(todaySales as double).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${LanguageService.getText(widget.language, 'transactions')}: ${todayTransactions.length}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${LanguageService.getText(widget.language, 'last_sync')}: ${lastSync != null ? _formatTime(lastSync) : LanguageService.getText(widget.language, 'pending')}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (todayTransactions.isNotEmpty) ...[
                  Text(
                    _getLocalizedText('recent_transactions'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...todayTransactions.reversed.take(3).map((transaction) {
                    return ListTile(
                      leading: const Icon(Icons.payment, color: Colors.green),
                      title: Text('₹${(transaction['amount'] ?? 0).toStringAsFixed(2)}'),
                      subtitle: Text(_formatTime(DateTime.parse(transaction['timestamp']))),
                      trailing: Text(LanguageService.getText(widget.language, 'successful'),
                          style: const TextStyle(color: Colors.green)),
                    );
                  }).toList(),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _playVoiceConfirmation(_getLocalizedText('closing_sales_summary'));
                },
                child: Text(LanguageService.getText(widget.language, 'cancel')),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showTransactionHistory(context);
                },
                child: Text(LanguageService.getText(widget.language, 'transaction_history')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransactionHistory(BuildContext context) {
    _playVoiceConfirmation(_getLocalizedText('showing_complete_history'));

    showDialog(
      context: context,
      builder: (context) => FutureBuilder(
        future: StorageService.getTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AlertDialog(
              title: Text('Loading...'),
              content: CircularProgressIndicator(),
            );
          }

          final allTransactions = snapshot.data ?? [];

          return AlertDialog(
            title: Text(LanguageService.getText(widget.language, 'transaction_history')),
            content: SizedBox(
              width: double.maxFinite,
              child: allTransactions.isEmpty
                  ? Center(
                child: Text(
                  _getLocalizedText('no_transactions'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: allTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = allTransactions.reversed.toList()[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.payment, color: Colors.green),
                      title: Text('₹${(transaction['amount'] ?? 0).toStringAsFixed(2)}'),
                      subtitle: Text(_formatTime(DateTime.parse(transaction['timestamp']))),
                      trailing: Text(LanguageService.getText(widget.language, 'successful'),
                          style: const TextStyle(color: Colors.green)),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(LanguageService.getText(widget.language, 'cancel')),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${_formatTime(dateTime)}';
  }
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(LanguageService.getText(widget.language, 'logout')),
          content: Text(LanguageService.getText(widget.language, 'logout_confirmation')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(LanguageService.getText(widget.language, 'cancel')),
            ),
            TextButton(
              onPressed: () async {
                await VoiceService().stop();
                await StorageService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                      (route) => false,
                );
              },
              child: Text(LanguageService.getText(widget.language, 'logout')),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LanguageChangeDialog(
        currentLanguage: widget.language,
        onLanguageChanged: (newLanguage) {
          if (newLanguage != widget.language) {
            _changeLanguage(newLanguage);
          }
        },
      ),
    );
  }

  void _changeLanguage(String newLanguage) async {
    await StorageService.setLanguage(newLanguage);
    await VoiceService().setLanguage(newLanguage);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MainDashboard(language: newLanguage)),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.getText(widget.language, 'dashboard')),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              _showLanguageChangeDialog(context);
            },
            tooltip: LanguageService.getText(widget.language, 'change_language'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
            tooltip: LanguageService.getText(widget.language, 'logout'),
          ),
        ],
      ),
      body: FutureBuilder(
        future: StorageService.getUpiId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final upiId = snapshot.data ?? 'Not set';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '👋 ${LanguageService.getText(widget.language, 'welcome')}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'UPI ID: $upiId',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${LanguageService.getText(widget.language, 'language')}: ${_getLanguageName(widget.language)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Quick Actions
                Text(
                  LanguageService.getText(widget.language, 'quick_actions'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons Grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildActionButton(
                        context,
                        Icons.qr_code,
                        LanguageService.getText(widget.language, 'receive_payment'),
                        Colors.green,
                            () {
                          _startPaymentProcess(context);
                        },
                      ),
                      _buildActionButton(
                        context,
                        Icons.history,
                        LanguageService.getText(widget.language, 'today_sales'),
                        Colors.purple,
                            () {
                          _showTodaySales(context);
                        },
                      ),
                      _buildActionButton(
                        context,
                        Icons.volume_up,
                        LanguageService.getText(widget.language, 'voice_help'),
                        Colors.blue,
                            () {
                          _playHelpInstructions();
                        },
                      ),
                      _buildActionButton(
                        context,
                        Icons.settings_voice,
                        LanguageService.getText(widget.language, 'voice_settings'),
                        Colors.orange,
                            () {
                          _voiceSetup(context);
                        },
                      ),
                      _buildActionButton(
                        context,
                        Icons.receipt_long,
                        LanguageService.getText(widget.language, 'transaction_history'),
                        Colors.red,
                            () {
                          _showTransactionHistory(context);
                        },
                      ),

                      _buildActionButton(
                        context,
                        Icons.sync,
                        LanguageService.getText(widget.language, 'sync_status'),
                        Colors.teal,
                            () {
                          _showSyncStatus(context);
                        },
                      ),
                      _buildActionButton(
                        context,
                        Icons.settings,
                        'Firebase Setup',  // You can translate this later
                        Colors.blueGrey,
                            () {
                          _showFirebaseConfigScreen(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSyncStatus(BuildContext context) {
    _playVoiceConfirmation(_getLocalizedText('showing_sync_status'));

    showDialog(
      context: context,
      builder: (context) => FutureBuilder(
        future: Future.wait([
          StorageService.getUpiId(),
          StorageService.getLastSync(),
        ]).then((results) async {
          final upiId = results[0] as String; // Add type casting
          final lastSync = results[1] as DateTime?;
          if (upiId.isNotEmpty) { // Now upiId is guaranteed to be a String
            final syncStatus = await FirebaseService().getSyncStatus(upiId);
            return {
              'upiId': upiId,
              'lastSync': lastSync,
              'syncStatus': syncStatus,
            };
          }
          return {
            'upiId': upiId,
            'lastSync': lastSync,
            'syncStatus': {'hasData': false, 'isConnected': false},
          };
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AlertDialog(
              title: Text('Loading...'),
              content: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data as Map<String, dynamic>?;
          final upiId = data?['upiId'] ?? '';
          final lastSync = data?['lastSync'];
          final syncStatus = data?['syncStatus'] ?? {};

          final hasData = syncStatus['hasData'] ?? false;
          final isConnected = syncStatus['isConnected'] ?? false;

          return AlertDialog(
            title: Text(LanguageService.getText(widget.language, 'sync_status')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  size: 50,
                  color: isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  isConnected
                      ? (hasData ? 'Data Synced' : 'No Cloud Data')
                      : 'Not Connected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'UPI ID: ${upiId.isNotEmpty ? upiId : 'Not set'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${LanguageService.getText(widget.language, 'last_sync')}: ${lastSync != null ? _formatDateTime(lastSync) : LanguageService.getText(widget.language, 'pending')}',
                  textAlign: TextAlign.center,
                ),
                if (isConnected && upiId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _uploadToCloud(upiId);
                          },
                          child: Text('Upload to Cloud'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _downloadFromCloud(upiId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: Text('Download from Cloud', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(LanguageService.getText(widget.language, 'cancel')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _uploadToCloud(String upiId) async {
    try {
      await FirebaseService().syncWithFirebase(upiId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data uploaded to cloud successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _playVoiceConfirmation('Data uploaded to cloud successfully');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _playVoiceConfirmation('Upload failed');
    }
  }

  Future<void> _downloadFromCloud(String upiId) async {
    try {
      await FirebaseService().downloadFromFirebase(upiId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data downloaded from cloud successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _playVoiceConfirmation('Data downloaded from cloud successfully');
      setState(() {}); // Refresh the UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _playVoiceConfirmation('Download failed');
    }
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String text,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'kn':
        return 'ಕನ್ನಡ';
      default:
        return 'English';
    }
  }
}

class LanguageChangeDialog extends StatefulWidget {
  final String currentLanguage;
  final Function(String) onLanguageChanged;

  const LanguageChangeDialog({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  _LanguageChangeDialogState createState() => _LanguageChangeDialogState();
}

class _LanguageChangeDialogState extends State<LanguageChangeDialog> {
  String? selectedLanguage;

  final List<Map<String, String>> languages = [
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'en', 'name': 'English'},
    {'code': 'kn', 'name': 'ಕನ್ನಡ'},
  ];

  @override
  void initState() {
    super.initState();
    selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(LanguageService.getText(widget.currentLanguage, 'select_language')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages.map((lang) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LanguageButton(
              languageName: lang['name']!,
              isSelected: selectedLanguage == lang['code'],
              onTap: () {
                setState(() {
                  selectedLanguage = lang['code'];
                });
              },
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(LanguageService.getText(widget.currentLanguage, 'cancel')),
        ),
        ElevatedButton(
          onPressed: selectedLanguage != null ? () {
            widget.onLanguageChanged(selectedLanguage!);
            Navigator.pop(context);
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: Text(
            LanguageService.getText(widget.currentLanguage, 'save_continue'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
// ==== PASTE THIS ENTIRE CLASS AT THE VERY END OF YOUR main.dart FILE ====

class FirebaseConfigScreen extends StatefulWidget {
  final String language;

  const FirebaseConfigScreen({super.key, required this.language});

  @override
  _FirebaseConfigScreenState createState() => _FirebaseConfigScreenState();
}

class _FirebaseConfigScreenState extends State<FirebaseConfigScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  Future<void> _pickJsonFile() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = '';
      });

      // Pick JSON file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        bool success = await FirebaseConfigService.saveAndInitializeFirebase(file);

        setState(() {
          _isSuccess = success;
          _statusMessage = success
              ? 'Firebase configured successfully! Your data will now sync to your own cloud.'
              : 'Failed to configure Firebase. Please check your google-services.json file.';
        });

        if (success) {
          // Wait a bit and go back
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect Your Firebase'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
        body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect Your Own Firebase',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload your google-services.json file to use your own Firebase project for data storage.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upload google-services.json',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get this file from your Firebase Console',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isSuccess ? Colors.green[50] : Colors.red[50],
                          border: Border.all(
                            color: _isSuccess ? Colors.green : Colors.red,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess ? Icons.check_circle : Icons.error,
                              color: _isSuccess ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: _isSuccess ? Colors.green[800] : Colors.red[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_statusMessage.isNotEmpty) const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _pickJsonFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Upload google-services.json',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

// ==== ADD THIS INSTRUCTIONS BUTTON ====
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FirebaseInstructionsScreen(language: widget.language),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: Colors.green[600]!),
                ),
                child: Text(
                  '📖 View Detailed Setup Instructions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
// ==== END OF INSTRUCTIONS BUTTON ====

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            Text(
              'Quick Steps:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStep('1. Go to Firebase Console (console.firebase.google.com)'),
            _buildStep('2. Create a new project or use existing one'),
            _buildStep('3. Add Android app with your package name'),
            _buildStep('4. Download google-services.json file'),
            _buildStep('5. Upload it here using the button above'),
          ],
                ),
          ),
        ),
      ),
    );

  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
// ==== END OF NEW CLASS ====