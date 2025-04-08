import 'package:flutter/material.dart';
import 'package:secure_way_client/driver/interfaces/profile_tab.dart';
import 'package:secure_way_client/services/request_services.dart';
import 'package:secure_way_client/services/sos_location_service.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';

class SosHomeScreen extends StatefulWidget {
  final UserModel? user;
  const SosHomeScreen({super.key, this.user});

  @override
  _SosHomeScreenState createState() => _SosHomeScreenState();
}

class _SosHomeScreenState extends State<SosHomeScreen> {
  int _selectedIndex = 0;
  final RequestService _requestService = RequestService();
  final SosLocationService _sosLocationService = SosLocationService();

  double? _driverLatitude;
  double? _driverLongitude;
  String _currentLocationText = 'Locating...';
  bool _locationStreamInitialized = false;

  List<Widget> get _widgetOptions => <Widget>[
        Column(
          key: ValueKey(_currentLocationText),
          children: [
            SafeArea(
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'SOS Current Location: $_currentLocationText',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Request>>(
                stream: _requestService.getSosRequests(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                        title: Text('SOS Request ID: ${request.id}'),
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
        ProfileTab(user: widget.user),
      ];

  @override
  void initState() {
    super.initState();
    if (!_locationStreamInitialized) {
      _initLocationStream();
      _locationStreamInitialized = true;
    }
  }

  void _initLocationStream() {
    _sosLocationService.locationStream.listen((locationData) {
      print("location data: $locationData");
      setState(() {
        _currentLocationText =
            locationData['address'] ?? 'Location unavailable';
        _driverLatitude = locationData['latitude'];
        _driverLongitude = locationData['longitude'];
      });

      _reloadSosRequests();
    });
  }

  void _reloadSosRequests() {
    setState(() {}); // Trigger rebuild to potentially update nearest request
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
        title: const Text('SOS Home'),
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
