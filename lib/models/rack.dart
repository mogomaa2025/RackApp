import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class RackModel {
  final String id;
  final String name;
  final String description;
  final double lengthMm;
  final double widthMm;
  final double quantityFor1Rack;

  RackModel({
    required this.id,
    required this.name,
    required this.description,
    required this.lengthMm,
    required this.widthMm,
    required this.quantityFor1Rack,
  });

  double get totalAreaMm2 => lengthMm * widthMm;
  double get totalAreaM2 => totalAreaMm2 / 1000000;
  double get totalArea => totalAreaM2 * quantityFor1Rack * 2;
  double get totalPaintKg => totalArea / 7;
  double get totalPaintG => totalPaintKg * 1000;

  factory RackModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse doubles, returning 0.0 if null or not a number
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return RackModel(
      id: json['id']?.toString() ?? '', // Use toString() for safety and provide default
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      lengthMm: parseDouble(json['lengthMm']),
      widthMm: parseDouble(json['widthMm']),
      quantityFor1Rack: parseDouble(json['quantityFor1Rack']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'lengthMm': lengthMm,
      'widthMm': widthMm,
      'quantityFor1Rack': quantityFor1Rack,
    };
  }
}

class RackCategory {
  final String id;
  final String name;
  final List<RackModel> models;

  RackCategory({
    required this.id,
    required this.name,
    required this.models,
  });

  factory RackCategory.fromJson(Map<String, dynamic> json) {
    var modelsList = json['models'];
    List<RackModel> parsedModels = [];
    if (modelsList is List) {
      parsedModels = modelsList
          .where((model) => model is Map<String, dynamic>) // Ensure item is a map
          .map((model) => RackModel.fromJson(model as Map<String, dynamic>))
          .toList();
    }
    
    return RackCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      models: parsedModels,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'models': models.map((model) => model.toJson()).toList(),
    };
  }
}

class RackData {
  final List<RackCategory> categories;

  RackData({
    required this.categories,
  });

  factory RackData.fromJson(Map<String, dynamic> json) {
    var categoriesList = json['categories'];
    List<RackCategory> parsedCategories = [];
    if (categoriesList is List) {
      parsedCategories = categoriesList
          .where((category) => category is Map<String, dynamic>) // Ensure item is a map
          .map((category) => RackCategory.fromJson(category as Map<String, dynamic>))
          .toList();
    }

    return RackData(
      categories: parsedCategories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((category) => category.toJson()).toList(),
    };
  }

  static Future<RackData> loadFromAssets() async {
    final jsonString = await rootBundle.loadString('assets/rack_data.json');
    final jsonResponse = json.decode(jsonString);
    return RackData.fromJson(jsonResponse);
  }

  Future<void> saveToAssets() async {
    final jsonString = json.encode(toJson());
    final file = File('assets/rack_data.json');
    await file.writeAsString(jsonString);
  }
}

class CalculatedRackData extends RackModel {
  final double totalAreaMm2;
  final double totalAreaM2;
  final double totalArea;
  final double totalPaintKg;
  final double totalPaintG;

  CalculatedRackData({
    required String id,
    required String name,
    required String description,
    required double lengthMm,
    required double widthMm,
    required double quantityFor1Rack,
    required this.totalAreaMm2,
    required this.totalAreaM2,
    required this.totalArea,
    required this.totalPaintKg,
    required this.totalPaintG,
  }) : super(
    id: id,
    name: name,
    description: description,
    lengthMm: lengthMm,
    widthMm: widthMm,
    quantityFor1Rack: quantityFor1Rack,
  );
}