// lib/authentification/interfaces/login.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:secure_way_client/sos/interfaces/home_sos.dart';
import '../../driver/interfaces/home_driver.dart';
import '../../sos/interfaces/home_mechanic.dart'; // Import MechanicHomeScreen
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
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.cover,
              image: NetworkImage(
                  "https://plus.unsplash.com/premium_photo-1675826908169-ac0de41a213a?q=80&w=3725&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"))),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                      labelText: 'Email',
                      fillColor: Colors.white,
                      filled: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre email';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      fillColor: Colors.white,
                      filled: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre mot de passe';
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
                        print(
                            'Login successful: ${userCredential.user?.email}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connexion réussie !'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        DocumentSnapshot? userData = await _authService
                            .getUserDocById(userCredential.user!.uid);
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
                          } else if (userType == 'mechanic') {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MechanicHomeScreen(),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Échec de connexion. Veuillez vérifier vos identifiants.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text('Connexion'),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegisterScreen()),
                    );
                  },
                  child: Text(
                    "Vous n'avez pas de compte ? Inscrivez-vous",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
