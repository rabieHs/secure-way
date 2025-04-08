// lib/services/authentication_services.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // Import UserModel

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential?> register(String name, String email, String password,
      String phone, String userType, String? carBrand, String? carModel) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'userType': userType,
          if (userType == 'driver') ...{
            'carBrand': carBrand,
            'carModel': carModel,
          }
        });
        return userCredential;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception: ${e.message}");
      return null;
    } catch (e) {
      print("Exception: $e");
      return null;
    }
  }

  Future<UserCredential?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception: ${e.message}");
      return null;
    } catch (e) {
      print("Exception: $e");
      return null;
    }
  }

  // Gets the current Firebase User object
  Future<User?> getCurrentFirebaseUser() async {
    return _auth.currentUser;
  }

  // Fetches user data from Firestore by UID
  Future<DocumentSnapshot?> getUserDocById(String uid) async {
    try {
      DocumentSnapshot userDocument =
          await _firestore.collection('users').doc(uid).get();
      return userDocument;
    } catch (e) {
      print("Error fetching user by ID: $e");
      return null;
    }
  }

  // Gets the current logged-in user's data as a UserModel
  Future<UserModel?> getCurrentUserModel() async {
    User? firebaseUser = await getCurrentFirebaseUser();
    if (firebaseUser != null) {
      try {
        DocumentSnapshot? userDoc = await getUserDocById(firebaseUser.uid);
        if (userDoc != null && userDoc.exists) {
          // Explicitly cast data() to Map<String, dynamic>
          Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
          if (data != null) {
            return UserModel.fromJson(data);
          }
        }
      } catch (e) {
        print("Error fetching current user model: $e");
        return null;
      }
    }
    return null; // No user logged in or error fetching/parsing data
  }

  // Gets user data as UserModel by specific UID (renamed from getUserById for clarity)
  Future<UserModel?> getUserModelById(String uid) async {
    try {
      DocumentSnapshot? userDoc = await getUserDocById(uid);
      if (userDoc != null && userDoc.exists) {
        // Explicitly cast data() to Map<String, dynamic>
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          return UserModel.fromJson(data);
        }
      }
    } catch (e) {
      print("Error fetching user model by ID: $e");
      return null;
    }
    return null; // User not found or error
  }
}
