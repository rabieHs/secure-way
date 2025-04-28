// lib/driver/interfaces/home_driver.dart
// lib/driver/interfaces/home_driver.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:location/location.dart' as lc; // Import location package
import 'package:geocoding/geocoding.dart'; // Import geocoding package
import '../../services/request_services.dart';
import '../../services/sos_location_service.dart'; // Import SosLocationService
import '../../services/authentication_services.dart'; // Import AuthenticationService
import '../../models/request_model.dart';
import 'requests_tab.dart';
import 'profile_tab.dart';
import '../../models/user_model.dart';

class DriverHomeScreen extends StatefulWidget {
  final UserModel? user;
  const DriverHomeScreen({super.key, this.user});

  @override
  @override
  _DriverHomeScreenState createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedIndex = 0;
  final RequestService _requestService =
      RequestService(); // Add RequestService instance
  final SosLocationService _sosLocationService =
      SosLocationService(); // Add SosLocationService instance
  final AuthenticationService _authService =
      AuthenticationService(); // Add AuthenticationService instance

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const RequestsTab(),
      ProfileTab(user: widget.user),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // New method to show the mechanic request dialog
  void _showRequestMechanicDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _carBrandController = TextEditingController();
    final TextEditingController _carModelController = TextEditingController();
    final TextEditingController _descriptionController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Demander un Mécanicien'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              // Added SingleChildScrollView
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: _carBrandController,
                    decoration:
                        const InputDecoration(labelText: 'Marque de voiture'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer la marque de voiture';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _carModelController,
                    decoration:
                        const InputDecoration(labelText: 'Modèle de voiture'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer le modèle de voiture';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                        labelText: 'Description du problème'),
                    maxLines: 3, // Allow multiple lines for description
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez décrire le problème';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              // Changed to ElevatedButton for emphasis
              child: const Text('Soumettre la demande'),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    // Get current user
                    User? currentUser =
                        await _authService.getCurrentFirebaseUser();
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Erreur : Utilisateur non connecté.')),
                      );
                      Navigator.of(context).pop();
                      return;
                    }

                    // Get current location using location package
                    lc.LocationData? locationData =
                        await _sosLocationService.getCurrentLocation();

                    if (locationData == null ||
                        locationData.latitude == null ||
                        locationData.longitude == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Erreur : Impossible d\'obtenir la position actuelle.')),
                      );
                      Navigator.of(context).pop();
                      return;
                    }

                    // Get address using geocoding package
                    String locationName = 'Address not found';
                    try {
                      List<Placemark> placemarks =
                          await placemarkFromCoordinates(
                        locationData.latitude!,
                        locationData.longitude!,
                      );
                      if (placemarks.isNotEmpty) {
                        Placemark place = placemarks[0];
                        locationName =
                            '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
                      }
                    } catch (e) {
                      print("Error getting address: $e");
                      locationName = 'Impossible de récupérer l\'adresse';
                    }

                    // Prepare data
                    String carBrand = _carBrandController.text.trim();
                    String carModel = _carModelController.text.trim();
                    String description = _descriptionController.text.trim();

                    // Save request
                    await _requestService.saveRequestToFirebase(
                      description: description,
                      locationName: locationName,
                      latitude: locationData
                          .latitude!, // Use latitude from locationData
                      longitude: locationData
                          .longitude!, // Use longitude from locationData
                      userId: currentUser.uid,
                      requestType: RequestType.mechanic, // Set type to mechanic
                      carBrand: carBrand, // Pass car brand
                      carModel: carModel, // Pass car model
                    );

                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Demande de mécanicien soumise avec succès !')),
                    );
                  } catch (e) {
                    print("Error submitting request: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Erreur lors de la soumission de la demande : $e')),
                    );
                  } finally {
                    // Dispose controllers
                    _carBrandController.dispose();
                    _carModelController.dispose();
                    _descriptionController.dispose();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Conducteur'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Demandes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
