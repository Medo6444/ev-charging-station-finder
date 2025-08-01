import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeLocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save home location to Firebase
  static Future<bool> saveHomeLocation({
    required LatLng coordinates,
    required String streetName,
    required String formattedAddress,
  }) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final homeLocationData = {
        'userId': currentUser.uid,
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
        'streetName': streetName,
        'formattedAddress': formattedAddress,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Use the user's UID as document ID to ensure one home location per user
      await _firestore
          .collection('home_locations')
          .doc(currentUser.uid)
          .set(homeLocationData, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error saving home location: $e');
      return false;
    }
  }

  // Get home location from Firebase
  static Future<Map<String, dynamic>?> getHomeLocation() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final DocumentSnapshot doc = await _firestore
          .collection('home_locations')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting home location: $e');
      return null;
    }
  }

  // Delete home location from Firebase
  static Future<bool> deleteHomeLocation() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      await _firestore
          .collection('home_locations')
          .doc(currentUser.uid)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting home location: $e');
      return false;
    }
  }

  // Check if user has a home location
  static Future<bool> hasHomeLocation() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final DocumentSnapshot doc = await _firestore
          .collection('home_locations')
          .doc(currentUser.uid)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking home location: $e');
      return false;
    }
  }
}