// lib/models/location_model.dart
class LocationModel {
  final double latitude;
  final double longitude;
  final String? placeName;

  LocationModel(
      {required this.latitude, required this.longitude, this.placeName});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: json['latitude'],
      longitude: json['longitude'],
      placeName: json['placeName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
    };
  }
}
