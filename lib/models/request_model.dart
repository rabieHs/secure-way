// lib/models/request_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_model.dart';

enum RequestStatus { pending, accepted, rejected, completed, replied }

enum RequestType { sos, mechanic }

class Request {
  final String id;
  final RequestType requestType;
  final LocationModel location;
  final Timestamp time;
  final RequestStatus status;
  final String userId;
  final String description;
  final String? response;
  final String? carBrand; // Add carBrand
  final String? carModel; // Add carModel

  Request({
    required this.id,
    required this.requestType,
    required this.location,
    required this.time,
    required this.status,
    required this.userId,
    required this.description,
    this.response, // Add response to constructor
    this.carBrand, // Add carBrand to constructor
    this.carModel, // Add carModel to constructor
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
      carBrand: json['carBrand'] as String?, // Add carBrand from JSON
      carModel: json['carModel'] as String?, // Add carModel from JSON
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
      'carBrand': carBrand, // Add carBrand to JSON
      'carModel': carModel, // Add carModel to JSON
    };
  }
}
