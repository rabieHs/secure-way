import 'package:firebase_auth/firebase_auth.dart'; // Import firebase_auth
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:secure_way_client/firebase_options.dart';
import 'authentification/interfaces/login.dart';
import 'authentification/interfaces/register.dart';
import 'services/authentication_services.dart';
import 'sos/interfaces/home_sos.dart';
import 'driver/interfaces/home_driver.dart';
import 'models/user_model.dart'; // Import UserModel
import 'package:cloud_firestore/cloud_firestore.dart'; // Import cloud_firestore

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Way Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  final AuthenticationService _authService = AuthenticationService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _authService.getCurrentUser(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        print('Connection state active: ${snapshot.connectionState}');
        if (snapshot.connectionState == ConnectionState.done) {
          final User? user = snapshot.data;
          if (user == null) {
            // User is not logged in, navigate to LoginScreen
            return LoginScreen();
          } else {
            // User is logged in, navigate to home screen based on user type
            return FutureBuilder<DocumentSnapshot?>(
              future: _authService.getUserById(user.uid),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot?> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done &&
                    userSnapshot.hasData &&
                    userSnapshot.data!.exists) {
                  UserModel userModel = UserModel.fromJson(
                      userSnapshot.data!.data() as Map<String, dynamic>);
                  String userType = userModel.userType;
                  if (userType == 'driver') {
                    return DriverHomeScreen();
                  } else if (userType == 'sos') {
                    return SosHomeScreen();
                  } else {
                    // Default case or error handling
                    return LoginScreen();
                  }
                }
                // Still fetching user data, show loading indicator
                return Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            );
          }
        }
        // Checking authentication, show loading indicator
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
