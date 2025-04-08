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
  final TextEditingController _carBrandController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  String _userType = 'sos';
  final AuthenticationService _authService = AuthenticationService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
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
              DropdownButtonFormField<String>(
                value: _userType,
                decoration: InputDecoration(labelText: 'User Type'),
                items: <String>['sos', 'driver', 'mechanic']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _userType = newValue!;
                  });
                },
              ),
              if (_userType == 'driver') ...[
                TextFormField(
                  controller: _carBrandController,
                  decoration: InputDecoration(labelText: 'Car Brand'),
                  validator: (value) {
                    if (_userType == 'driver' &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter your car brand';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _carModelController,
                  decoration: InputDecoration(labelText: 'Car Model'),
                  validator: (value) {
                    if (_userType == 'driver' &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter your car model';
                    }
                    return null;
                  },
                ),
              ],
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    String name = _nameController.text.trim();
                    String email = _emailController.text.trim();
                    String password = _passwordController.text.trim();
                    String phone = _phoneController.text.trim();
                    String? carBrand = _userType == 'driver'
                        ? _carBrandController.text.trim()
                        : null;
                    String? carModel = _userType == 'driver'
                        ? _carModelController.text.trim()
                        : null;

                    UserCredential? userCredential =
                        await _authService.register(name, email, password,
                            phone, _userType, carBrand, carModel);
                    if (userCredential != null) {
                      print(
                          'Registration successful: ${userCredential.user?.email} - Type: $_userType');
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
                    }
                  }
                },
                child: Text('Register'),
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
                child: Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
