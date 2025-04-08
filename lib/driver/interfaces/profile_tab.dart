// lib/driver/interfaces/profile_tab.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart'; // Import UserModel
import '../../models/car_model.dart'; // Import CarModel

class ProfileTab extends StatelessWidget {
  final UserModel? user;
  const ProfileTab({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Name'),
            subtitle: Text(user?.name ?? 'N/A'),
          ),
          ListTile(
            title: const Text('Email'),
            subtitle: Text(user?.email ?? 'N/A'),
          ),
          ListTile(
            title: const Text('Phone'),
            subtitle: Text(user?.phone ?? 'N/A'),
          ),
          if (user?.userType == 'driver') ...[
            const SizedBox(height: 20),
            const Text(
              'Car Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Car Brand'),
              subtitle: Text(user?.carBrand ?? 'N/A'),
            ),
            ListTile(
              title: const Text('Car Model'),
              subtitle: Text(user?.carModel ?? 'N/A'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Change User Info'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implement Change User Info
            },
          ),
          ListTile(
            title: const Text('My Car'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implement My Car
            },
          ),
        ],
      ),
    );
  }
}
