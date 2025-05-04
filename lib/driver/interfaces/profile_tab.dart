// lib/driver/interfaces/profile_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:secure_way_client/authentification/interfaces/login.dart';
import '../../models/user_model.dart'; // Import UserModel
import '../../models/car_model.dart'; // Import CarModel

class ProfileTab extends StatelessWidget {
  final UserModel? user;
  const ProfileTab({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Material(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informations du Profil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Nom'),
                subtitle: Text(user?.name ?? 'N/A'),
              ),
              ListTile(
                title: const Text('Email'),
                subtitle: Text(user?.email ?? 'N/A'),
              ),
              ListTile(
                title: const Text('Téléphone'),
                subtitle: Text(user?.phone ?? 'N/A'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Paramètres',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(color: Colors.red),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  await FirebaseAuth.instance.signOut().whenComplete(() {
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (r) => false);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
