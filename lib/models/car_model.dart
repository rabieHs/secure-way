// lib/models/car_model.dart

class CarModel {
  final String brand;
  final String model;

  CarModel({required this.brand, required this.model});

  factory CarModel.fromJson(Map<String, dynamic> json) {
    return CarModel(
      brand: json['brand'],
      model: json['model'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
    };
  }
}
