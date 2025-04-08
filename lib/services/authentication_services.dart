// lib/services/authentication_services.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }

  Future<DocumentSnapshot?> getUserById(String uid) async {
    try {
      DocumentSnapshot userDocument =
          await _firestore.collection('users').doc(uid).get();
      return userDocument;
    } catch (e) {
      print("Error fetching user by ID: $e");
      return null;
    }
  }
}
