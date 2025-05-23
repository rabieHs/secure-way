// lib/services/request_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator
import '../models/request_model.dart';
import '../models/location_model.dart';
import 'sos_location_service.dart'; // Import SosLocationService
import 'notification_service.dart'; // Import NotificationService

class RequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SosLocationService sosLocationService =
      SosLocationService(); // Instance of SosLocationService (public)

  Future<void> saveRequestToFirebase({
    required String description,
    required String locationName,
    required double latitude,
    required double longitude,
    required String userId,
    required RequestType requestType,
    String? carBrand, // Add carBrand parameter
    String? carModel, // Add carModel parameter
  }) async {
    try {
      final id = const Uuid().v4();
      LocationModel location = LocationModel(
        latitude: latitude,
        longitude: longitude,
        placeName: locationName,
      );

      Request request = Request(
        id: id,
        requestType: requestType,
        location: location,
        time: Timestamp.now(),
        status: RequestStatus.pending,
        userId: userId,
        description: description,
        carBrand: carBrand, // Pass carBrand
        carModel: carModel, // Pass carModel
      );

      await _firestore.collection('requests').doc(id).set(request.toJson());
    } catch (e) {
      // ignore: avoid_print
      print(e);
      rethrow;
    }
  }

  // Renamed getSosRequests to getNearbyRequestsByType and added requestType parameter
  Stream<List<Request>> getNearbyRequestsByType(RequestType requestType,
      double currentLatitude, double currentLongitude) {
    print('Fetching nearby requests for type: ${requestType.name}');
    print('Current location: $currentLatitude, $currentLongitude');

    return _firestore
        .collection('requests')
        .where("status",
            isEqualTo: RequestStatus.pending.name) // Only get pending requests
        .where('requestType',
            isEqualTo: requestType.name) // Use the passed requestType
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} requests from Firestore');
      List<Request> allSosRequests =
          snapshot.docs.map((doc) => Request.fromJson(doc.data())).toList();
      List<Request> nearbyRequests = allSosRequests.where((request) {
        // Calculate distance
        double distanceInMeters = Geolocator.distanceBetween(
          currentLatitude,
          currentLongitude,
          request.location.latitude,
          request.location.longitude,
        );
        print(
            'Request ${request.id} is ${distanceInMeters.toStringAsFixed(2)} meters away');
        // Filter by 25km (25000 meters)
        return distanceInMeters <= 25000;
      }).toList();

      print('Found ${nearbyRequests.length} nearby requests');
      // Notify about nearby requests
      _notifyAboutNearbyRequests(
          nearbyRequests, currentLatitude, currentLongitude);

      return nearbyRequests;
    });
  }

  // Notify about nearby requests
  void _notifyAboutNearbyRequests(
      List<Request> requests, double currentLat, double currentLng) async {
    print('Processing notifications for ${requests.length} nearby requests');
    if (requests.isEmpty) return;

    // Import notification service
    final notificationService = NotificationService();

    // Show notification for each nearby request
    for (var request in requests) {
      try {
        // Calculate distance
        double distanceInMeters = Geolocator.distanceBetween(
          currentLat,
          currentLng,
          request.location.latitude,
          request.location.longitude,
        );

        print(
            'Showing notification for request ${request.id} at ${distanceInMeters.toStringAsFixed(2)} meters');
        // Show notification
        await notificationService.showNearbyRequestNotification(
            request, distanceInMeters);
      } catch (e) {
        print('Error showing notification for request ${request.id}: $e');
      }
    }
  }

  Stream<List<Request>> getRequestsByUserIdAndDate(
      String userId, DateTime date) {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: userId)
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('time', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Request.fromJson(doc.data())).toList();
    });
  }

  Stream<List<Request>> getRequestsByUserIdSorted(String userId,
      {bool descending = false}) {
    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: userId)
        .orderBy('time', descending: descending)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Request.fromJson(doc.data())).toList();
    });
  }
  //TODO: add logic here to update status and delete sos location

  Future<void> updateRequestStatus(
      String requestId, RequestStatus status) async {
    try {
      print('Updating request status: $requestId to ${status.name}');
      // Update the request status in Firestore
      await _firestore.collection('requests').doc(requestId).update({
        'status': status.name,
      });

      // Get the updated request to send notification
      DocumentSnapshot requestDoc =
          await _firestore.collection('requests').doc(requestId).get();
      if (requestDoc.exists) {
        Request updatedRequest =
            Request.fromJson(requestDoc.data() as Map<String, dynamic>);
        print('Request updated successfully, sending notification');

        // Send notification about status change
        final notificationService = NotificationService();
        await notificationService.showStatusChangeNotification(updatedRequest);
      }
    } catch (e) {
      print('Error updating request status: $e');
      rethrow;
    }
  }

  // Add new method to update request with response
  Future<void> updateRequestWithResponse(
      String requestId, String response) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': RequestStatus.replied.name,
        'response': response,
      });
    } catch (e) {
      print('Error updating request with response: $e');
      rethrow;
    }
  }
}
