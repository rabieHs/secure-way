import 'package:firebase_auth/firebase_auth.dart'; // Import firebase_auth
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:secure_way_client/firebase_options.dart';
import 'package:secure_way_client/sos/interfaces/home_mechanic.dart';
import 'authentification/interfaces/login.dart';
import 'authentification/interfaces/register.dart';
import 'services/authentication_services.dart';
import 'sos/interfaces/home_sos.dart';
import 'driver/interfaces/home_driver.dart';
import 'models/user_model.dart'; // Import UserModel
import 'package:cloud_firestore/cloud_firestore.dart'; // Import cloud_firestore

import 'services/notification_service.dart'; // Import NotificationService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestNotificationPermission();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Client Secure Way',
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
      future: _authService.getCurrentFirebaseUser(),
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
              future: _authService.getUserDocById(user.uid),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot?> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done &&
                    userSnapshot.hasData &&
                    userSnapshot.data!.exists) {
                  UserModel userModel = UserModel.fromJson(
                      userSnapshot.data!.data() as Map<String, dynamic>);
                  String userType = userModel.userType;
                  print('User type: $userType');
                  if (userType == 'driver') {
                    return DriverHomeScreen(
                      user: userModel,
                    );
                  } else if (userType == 'sos') {
                    return SosHomeScreen(
                      user: userModel,
                    );
                  } else if (userType == 'mechanic') {
                    return MechanicHomeScreen(
                      user: userModel,
                    );
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
