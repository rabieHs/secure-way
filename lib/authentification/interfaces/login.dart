// lib/authentification/interfaces/login.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:secure_way_client/sos/interfaces/home_sos.dart';
import '../../driver/interfaces/home_driver.dart';
import '../../services/authentication_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/authentication_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart'; // Import UserModel
import 'register.dart'; // Import RegisterScreen

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthenticationService _authService = AuthenticationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    String email = _emailController.text.trim();
                    String password = _passwordController.text.trim();
                    UserCredential? userCredential =
                        await _authService.login(email, password);
                    if (userCredential != null) {
                      // Login successful
                      print('Login successful: ${userCredential.user?.email}');

                      DocumentSnapshot? userData = await _authService
                          .getUserById(userCredential.user!.uid);
                      if (userData != null && userData.exists) {
                        UserModel userModel = UserModel.fromJson(
                            userData.data() as Map<String, dynamic>);
                        String userType = userModel.userType;
                        if (userType == 'driver') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DriverHomeScreen(user: userModel),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        } else if (userType == 'sos') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SosHomeScreen(), // Placeholder for SOS home
                            ),
                            (Route<dynamic> route) => false,
                          );
                        } else {
                          // Handle unknown user type
                          print('Unknown user type: $userType');
                        }
                      }
                    } else {
                      // Login failed
                      print('Login failed');
                      // TODO: Show error message
                    }
                  }
                },
                child: Text('Login'),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
                child: Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
