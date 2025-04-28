import 'package:flutter/material.dart';
import '../../driver/interfaces/home_driver.dart';
import '../../services/authentication_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import '../../sos/interfaces/home_mechanic.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _userType = 'sos';
  final AuthenticationService _authService = AuthenticationService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.cover,
              image: NetworkImage(
                  "https://plus.unsplash.com/premium_photo-1664126223770-25311333f721?q=80&w=3687&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"))),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                      labelText: 'Nom', fillColor: Colors.white, filled: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre nom';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      fillColor: Colors.white,
                      filled: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre numéro de téléphone';
                    }
                    return null;
                  },
                ),
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
                DropdownButtonFormField<String>(
                  value: _userType,
                  decoration: InputDecoration(
                      labelText: 'Type d\'utilisateur',
                      fillColor: Colors.white,
                      filled: true),
                  items: <String>['sos', 'driver', 'mechanic']
                      .map<DropdownMenuItem<String>>((String value) {
                    String displayText = value;
                    if (value == 'driver') displayText = 'conducteur';
                    if (value == 'mechanic') displayText = 'mécanicien';

                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(displayText),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _userType = newValue!;
                    });
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      String name = _nameController.text.trim();
                      String email = _emailController.text.trim();
                      String password = _passwordController.text.trim();
                      String phone = _phoneController.text.trim();

                      UserCredential? userCredential = await _authService
                          .register(name, email, password, phone, _userType);
                      if (userCredential != null) {
                        print(
                            'Registration successful: ${userCredential.user?.email} - Type: $_userType');
                        ScaffoldMessenger.of(context).showSnackBar(
                          // Add success SnackBar
                          const SnackBar(
                            content: Text('Inscription réussie !'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        if (_userType == 'driver') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    DriverHomeScreen(user: null)),
                            (Route<dynamic> route) => false,
                          );
                        } else if (_userType == 'sos') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const Text('SOS Home Screen')),
                            (Route<dynamic> route) => false,
                          );
                        } else if (_userType == 'mechanic') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MechanicHomeScreen()),
                            (Route<dynamic> route) => false,
                          );
                        }
                      } else {
                        print('Registration failed');
                        ScaffoldMessenger.of(context).showSnackBar(
                          // Add error SnackBar
                          const SnackBar(
                            content: Text(
                                'Échec de l\'inscription. Veuillez réessayer.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text('S\'inscrire'),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: Text(
                    "Vous avez déjà un compte ? Connectez-vous",
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
