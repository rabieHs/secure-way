import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart' as lc;
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../models/request_model.dart';
import 'notification_service.dart';

class SosLocationService {
  final lc.Location _locationService = lc.Location();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final String _collectionName = 'sos_locations';

  lc.LocationData? _currentLocation;
  StreamSubscription<lc.LocationData>? _locationSubscription;
  final StreamController<Map<String, dynamic>> _locationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  SosLocationService() {
    _initLocationService();
    _initNotifications();
  }
  
  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestNotificationPermission();
  }

  Stream<Map<String, dynamic>> get locationStream =>
      _locationStreamController.stream;

  Future<void> _initLocationService() async {
    bool serviceEnabled;
    lc.PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return;
      }
    }

    // Check location permissions
    permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == lc.PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != lc.PermissionStatus.granted) {
        print('Location permissions are denied.');
        return;
      }
    }

    // Configure location settings for background updates
    await _locationService.changeSettings(
      accuracy: lc.LocationAccuracy.high,
      interval: 10000, // 10 seconds
      distanceFilter: 50, // 50 meters (reduced for more accurate arrival detection)
    );

    // Start listening to location updates
    _locationSubscription = _locationService.onLocationChanged.listen(
      (lc.LocationData locationData) async {
        print('Location update received: ${locationData.latitude}, ${locationData.longitude}');
        
        if (locationData.latitude != null && locationData.longitude != null) {
          // Get readable address
          String address = await _getAddressFromCoordinates(
              locationData.latitude!, locationData.longitude!);

          _currentLocation = locationData;

          // Add location data to stream
          _locationStreamController.add({
            'latitude': locationData.latitude,
            'longitude': locationData.longitude,
            'address': address,
          });

          // Check for active requests and update status if arrived
          await _checkAndUpdateRequestStatus(locationData.latitude!, locationData.longitude!);
        }
      },
      onError: (error) {
        print('Location tracking error: $error');
      },
    );
  }

  Future<void> _checkAndUpdateRequestStatus(double sosLat, double sosLng) async {
    print('Checking for active requests to update status...');
    try {
      // Get all active requests where status is 'accepted'
      var requestsSnapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in requestsSnapshot.docs) {
        var request = Request.fromJson(doc.data());
        print('Checking distance for request: ${request.id}');

        // Check if SOS has arrived at destination
        bool hasArrived = _notificationService.hasArrivedAtDestination(
          sosLat,
          sosLng,
          request.location.latitude,
          request.location.longitude,
        );

        if (hasArrived) {
          print('SOS has arrived at destination for request: ${request.id}');
          // Update request status to completed
          await FirebaseFirestore.instance
              .collection('requests')
              .doc(request.id)
              .update({'status': RequestStatus.completed.name});

          // Show notification for status change
          await _notificationService.showStatusChangeNotification(request);
        }
      }
    } catch (e) {
      print('Error checking and updating request status: $e');
    }
  }

  Future<String> _getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
      return 'Address not found';
    } catch (e) {
      print('Error getting address: $e');
      return 'Unable to retrieve address';
    }
  }

  Future<lc.LocationData?> getCurrentLocation() async {
    try {
      return await _locationService.getLocation();
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  Future<void> updateSosLocation(
      String userId, double latitude, double longitude) async {
    await _firestore.collection(_collectionName).doc(userId).set({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void dispose() {
    _locationSubscription?.cancel();
    _locationStreamController.close();
  }
}
