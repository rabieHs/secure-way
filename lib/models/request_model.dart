// lib/models/request_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_model.dart';

enum RequestStatus { pending, accepted, rejected, completed }

enum RequestType { sos, mechanic }

class Request {
  final String id;
  final RequestType requestType;
  final LocationModel location;
  final Timestamp time;
  final RequestStatus status;
  final String userId;
  final String description;

  Request({
    required this.id,
    required this.requestType,
    required this.location,
    required this.time,
    required this.status,
    required this.userId,
    required this.description,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'] as String,
      requestType: RequestType.values.firstWhere(
        (e) => e.name == json['requestType'],
        orElse: () => RequestType.mechanic, // Default value
      ),
      location:
          LocationModel.fromJson(json['location'] as Map<String, dynamic>),
      time: json['time'] as Timestamp,
      status: RequestStatus.values.byName(json['status'] as String),
      userId: json['userId'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestType': requestType.name,
      'location': location.toJson(),
      'time': time,
      'status': status.name,
      'userId': userId,
      'description': description,
    };
  }
}
