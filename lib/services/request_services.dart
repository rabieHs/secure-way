// lib/services/request_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator
import '../models/request_model.dart';
import '../models/location_model.dart';
import 'sos_location_service.dart'; // Import SosLocationService

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
    return _firestore
        .collection('requests')
        .where('requestType',
            isEqualTo: requestType.name) // Use the passed requestType
        .snapshots()
        .map((snapshot) {
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
        // Filter by 25km (25000 meters)
        return distanceInMeters <= 25000;
      }).toList();
      return nearbyRequests;
    });
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
}
