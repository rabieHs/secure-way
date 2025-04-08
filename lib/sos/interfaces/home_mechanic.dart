import 'package:flutter/material.dart';
import '../../models/request_model.dart';
import '../../services/request_services.dart';

class MechanicHomeScreen extends StatefulWidget {
  MechanicHomeScreen();

  @override
  _MechanicHomeScreenState createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends State<MechanicHomeScreen> {
  final RequestService _requestService = RequestService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanic Home'),
      ),
      body: const Center(
        child: Text('Mechanic Home Screen'),
      ),
    );
  }
}
