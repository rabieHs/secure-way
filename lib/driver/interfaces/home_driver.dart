// lib/driver/interfaces/home_driver.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart' as lc;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/request_services.dart';
import '../../services/sos_location_service.dart';
import '../../services/authentication_services.dart';
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
  final RequestService _requestService = RequestService();
  final SosLocationService _sosLocationService = SosLocationService();
  final AuthenticationService _authService = AuthenticationService();

  // Controllers for location
  final TextEditingController _locationController = TextEditingController();
  double? _latitude;
  double? _longitude;

  // Helper methods for translation
  String _translateRequestType(RequestType type) {
    switch (type) {
      case RequestType.sos:
        return 'SOS';
      case RequestType.mechanic:
        return 'Mécanicien';
    }
  }

  // Method to get current location
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Les services de localisation sont désactivés.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Les permissions de localisation sont refusées');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Les permissions de localisation sont définitivement refusées.');
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
    return position;
  }

  // Method to show SOS request dialog
  void _showAddRequestDialog(BuildContext context, RequestType requestType) {
    final descriptionController = TextEditingController();
    final carBrandController = TextEditingController();
    final carModelController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
              'Ajouter une nouvelle demande de ${_translateRequestType(requestType).toUpperCase()}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),

                // Only show car brand and model fields for mechanic requests
                if (requestType == RequestType.mechanic) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: carBrandController,
                    decoration:
                        const InputDecoration(labelText: 'Marque de voiture'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: carModelController,
                    decoration:
                        const InputDecoration(labelText: 'Modèle de voiture'),
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration:
                            const InputDecoration(labelText: 'Emplacement'),
                        enabled: false,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.location_on),
                      onPressed: () async {
                        try {
                          Position position = await _getCurrentLocation();
                          List<Placemark> placemarks =
                              await placemarkFromCoordinates(
                                  position.latitude, position.longitude);
                          Placemark place = placemarks.first;
                          String placeName =
                              '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
                          setState(() {
                            _locationController.text = placeName;
                          });
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Store context for later use
                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                final navigator = Navigator.of(dialogContext);

                String description = descriptionController.text.trim();
                String locationName = _locationController.text.trim();

                // Get car brand and model for mechanic requests
                String? carBrand;
                String? carModel;
                if (requestType == RequestType.mechanic) {
                  carBrand = carBrandController.text.trim();
                  carModel = carModelController.text.trim();

                  // Validate car brand and model for mechanic requests
                  if (carBrand.isEmpty || carModel.isEmpty) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Veuillez entrer la marque et le modèle de voiture'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                if (description.isEmpty) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez entrer une description'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                User? currentUser = await _authService.getCurrentFirebaseUser();
                if (currentUser == null) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Erreur: Utilisateur non connecté'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (_latitude != null &&
                    _longitude != null &&
                    locationName.isNotEmpty) {
                  try {
                    await _requestService.saveRequestToFirebase(
                      description: description,
                      locationName: locationName,
                      latitude: _latitude!,
                      longitude: _longitude!,
                      userId: currentUser.uid,
                      requestType: requestType,
                      carBrand: carBrand,
                      carModel: carModel,
                    );

                    // Close the dialog
                    navigator.pop();

                    // Show success message
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            'Demande de ${_translateRequestType(requestType).toUpperCase()} soumise avec succès'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Veuillez d\'abord obtenir votre position actuelle'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            children: [
              // Demandes
              _buildGridItem(
                context,
                'Demandes',
                Icons.list_alt,
                Colors.blue,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RequestsTab()),
                  );
                },
              ),
              // Ajouter demande SOS
              _buildGridItem(
                context,
                'Ajouter demande SOS',
                Icons.sos,
                Colors.red,
                () {
                  _showAddRequestDialog(context, RequestType.sos);
                },
              ),
              // Ajouter demande mécanique
              _buildGridItem(
                context,
                'Ajouter demande mécanique',
                Icons.car_repair,
                Colors.green,
                () {
                  _showRequestMechanicDialog(context);
                },
              ),
              // Profil
              _buildGridItem(
                context,
                'Profil',
                Icons.person,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileTab(user: widget.user),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withAlpha(178),
                color
              ], // 178 is approximately 0.7 * 255
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 50,
                color: Colors.white,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
