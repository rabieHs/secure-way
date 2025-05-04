import 'package:flutter/material.dart';
import '../../driver/interfaces/home_driver.dart';
import '../../services/authentication_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../sos/interfaces/home_sos.dart';
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

  String? _validateEmail(String? value) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre email';
    } else if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer un email valide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre mot de passe';
    } else if (!passwordRegex.hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins 8 caractères, une lettre et un chiffre';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phoneRegex = RegExp(r'^[0-9]{8,15}$');
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone';
    } else if (!phoneRegex.hasMatch(value)) {
      return 'Numéro de téléphone invalide';
    }
    return null;
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
            "https://plus.unsplash.com/premium_photo-1664126223770-25311333f721?q=80&w=3687&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // SOS Logo
                  Container(
                    width: 150,
                    height: 150,
                    margin: const EdgeInsets.only(bottom: 30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.car_repair,
                            size: 60,
                            color: Colors.red,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                        labelText: 'Nom',
                        fillColor: Colors.white,
                        filled: true),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Veuillez entrer votre nom'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        fillColor: Colors.white,
                        filled: true),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                        labelText: 'Email',
                        fillColor: Colors.white,
                        filled: true),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        fillColor: Colors.white,
                        filled: true),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 20),
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
                          ScaffoldMessenger.of(context).showSnackBar(
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
                                  builder: (context) => const SosHomeScreen()),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Échec de l\'inscription. Veuillez réessayer.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('S\'inscrire'),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                    child: const Text(
                      "Vous avez déjà un compte ? Connectez-vous",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
