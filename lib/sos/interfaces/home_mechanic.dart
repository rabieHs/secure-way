import 'package:flutter/material.dart';
import '../../driver/interfaces/profile_tab.dart' show ProfileTab;
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../services/authentication_services.dart';
import '../../services/request_services.dart';
import '../../services/sos_location_service.dart';

class MechanicHomeScreen extends StatefulWidget {
  MechanicHomeScreen();

  @override
  _MechanicHomeScreenState createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends State<MechanicHomeScreen> {
  int _selectedIndex = 0;
  final RequestService _requestService = RequestService();
  final SosLocationService _sosLocationService = SosLocationService();

  double? _driverLatitude;
  double? _driverLongitude;
  String _currentLocationText = 'Locating...';
  bool _locationStreamInitialized = false;
  Stream<List<Request>>?
      _nearbySosRequestStream; // Add state variable for the stream

  List<Widget> get _widgetOptions => <Widget>[
        Column(
          key: ValueKey(_currentLocationText),
          children: [
            SafeArea(
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Mechanic Current Location: $_currentLocationText',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Request>>(
                stream:
                    _nearbySosRequestStream, // Use the state stream variable
                builder: (context, snapshot) {
                  // Handle initial null stream or waiting state
                  if (_nearbySosRequestStream == null ||
                      snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: _driverLatitude == null
                            ? const Text("Waiting for location...")
                            : const CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No SOS requests found.'));
                  }

                  List<Request> sosRequests = snapshot.data!;

                  return ListView.builder(
                    itemCount: sosRequests.length,
                    itemBuilder: (context, index) {
                      Request request = sosRequests[index];
                      return ListTile(
                        title: Text('Mechanic Request ID: ${request.id}'),
                        subtitle:
                            Text('Location: ${request.location.placeName}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        ProfileTab()
      ];

  @override
  void initState() {
    super.initState();
    // Initialize location stream only once
    if (!_locationStreamInitialized) {
      _initLocationStream();
      _locationStreamInitialized = true;
    }
    // Optionally initialize stream here if default coords are known,
    // otherwise it will be initialized on first location update.
  }

  void _initLocationStream() {
    _sosLocationService.locationStream.listen((locationData) async {
      print("location data: $locationData");
      // Use local variables for null safety check before updating stream
      double? newLat = locationData['latitude'];
      double? newLng = locationData['longitude'];
      String newAddress = locationData['address'] ?? 'Location unavailable';
      final UserModel? user =
          await AuthenticationService().getCurrentUserModel();

      if (newLat != null && newLng != null) {
        // Check if location actually changed to avoid unnecessary stream updates
        if (newLat != _driverLatitude || newLng != _driverLongitude) {
          setState(() {
            _currentLocationText = newAddress;
            _driverLatitude = newLat;
            _driverLongitude = newLng;

            // Determine RequestType based on userType

            RequestType currentRequestType = _getRequestTypeFromUser(user);

            print("current request type: $currentRequestType");

            // Update the stream with the new location and determined types
            _nearbySosRequestStream = _requestService.getNearbyRequestsByType(
                currentRequestType, _driverLatitude!, _driverLongitude!);
          });
        } else if (_currentLocationText != newAddress) {
          // Update address even if lat/lng are the same
          setState(() {
            _currentLocationText = newAddress;
          });
        }
      } else {
        // Handle case where location data is incomplete
        setState(() {
          _currentLocationText =
              newAddress; // Still update address if available
        });
      }
    });
  }

  // Helper function to determine RequestType from UserModel
  RequestType _getRequestTypeFromUser(UserModel? user) {
    // Default to mechanic if user or userType is null, or handle error as needed
    if (user == null || user.userType == null) {
      print(
          "Warning: User or userType is null, defaulting to mechanic requests.");
      return RequestType.mechanic; // Or throw an error
    }
    switch (user.userType.toLowerCase()) {
      case 'sos':
        return RequestType.sos;
      case 'mechanic':
        return RequestType.mechanic;
      default:
        print(
            "Warning: Unknown userType '${user.userType}', defaulting to mechanic requests.");
        return RequestType.mechanic; // Default or throw error for unknown types
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanic Home'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  @override
  void dispose() {
    _sosLocationService.dispose();
    super.dispose();
  }
}
