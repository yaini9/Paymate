import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the StorageService from your main file
import 'main.dart'; // This imports the StorageService class

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize Firebase
  Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  // Add transaction to Firestore using UPI ID as identifier
  Future<void> addTransaction(String upiId, Map<String, dynamic> transaction) async {
    try {
      await _firestore
          .collection('transactions')
          .doc(upiId) // Use UPI ID as document ID
          .collection('user_transactions')
          .add({
        ...transaction,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Add transaction error: $e');
      rethrow;
    }
  }

  // Get all transactions for a UPI ID from Firestore
  Future<List<Map<String, dynamic>>> getTransactions(String upiId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('transactions')
          .doc(upiId)
          .collection('user_transactions')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Get transactions error: $e');
      return [];
    }
  }

  // Get today's transactions for a UPI ID from Firestore
  Future<List<Map<String, dynamic>>> getTodayTransactions(String upiId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      QuerySnapshot querySnapshot = await _firestore
          .collection('transactions')
          .doc(upiId)
          .collection('user_transactions')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Get today transactions error: $e');
      return [];
    }
  }

  // Sync local transactions with Firebase
  Future<void> syncWithFirebase(String upiId) async {
    try {
      // Get local transactions
      final localTransactions = await StorageService.getTransactions();

      // Get existing Firebase transactions to avoid duplicates
      final firebaseTransactions = await getTransactions(upiId);
      final existingTimestamps = firebaseTransactions
          .map((t) => t['timestamp'])
          .toSet();

      // Upload only new transactions
      for (var transaction in localTransactions) {
        if (!existingTimestamps.contains(transaction['timestamp'])) {
          await addTransaction(upiId, transaction);
        }
      }

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSync', DateTime.now().toIso8601String());
    } catch (e) {
      print('Sync error: $e');
      rethrow;
    }
  }

  // Download transactions from Firebase to local storage
  Future<void> downloadFromFirebase(String upiId) async {
    try {
      // Get transactions from Firebase
      final firebaseTransactions = await getTransactions(upiId);

      // Get local transactions to avoid duplicates
      final localTransactions = await StorageService.getTransactions();
      final existingTimestamps = localTransactions
          .map((t) => t['timestamp'])
          .toSet();

      // Add only new transactions to local storage
      for (var transaction in firebaseTransactions) {
        if (!existingTimestamps.contains(transaction['timestamp'])) {
          await StorageService.addTransaction(transaction);
        }
      }

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSync', DateTime.now().toIso8601String());
    } catch (e) {
      print('Download error: $e');
      rethrow;
    }
  }

  // Check if UPI ID has any data in Firebase
  Future<bool> hasDataInFirebase(String upiId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('transactions')
          .doc(upiId)
          .collection('user_transactions')
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Check data error: $e');
      return false;
    }
  }

  // Get sync status
  Future<Map<String, dynamic>> getSyncStatus(String upiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('lastSync');

      final hasData = await hasDataInFirebase(upiId);

      return {
        'hasData': hasData,
        'lastSync': lastSync != null ? DateTime.parse(lastSync) : null,
        'isConnected': true,
      };
    } catch (e) {
      return {
        'hasData': false,
        'lastSync': null,
        'isConnected': false,
      };
    }
  }

  // Update user preferences in Firebase
  Future<void> updateUserPreferences(String upiId, String language) async {
    try {
      await _firestore.collection('user_preferences').doc(upiId).set({
        'language': language,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Update preferences error: $e');
    }
  }

  // Get user preferences from Firebase
  Future<Map<String, dynamic>?> getUserPreferences(String upiId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('user_preferences').doc(upiId).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Get preferences error: $e');
      return null;
    }
  }
}