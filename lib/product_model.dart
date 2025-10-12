import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String barcode;
  final String name;
  final String category;
  final double weight;
  final int shelfLifeDays;
  final DateTime addedDate;
  final DateTime expDate;

  Product({
    required this.barcode,
    required this.name,
    required this.category,
    required this.weight,
    required this.shelfLifeDays,
    required this.addedDate,
    required this.expDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'weight': weight,
      'shelfLifeDays': shelfLifeDays,
      'addedDate': Timestamp.fromDate(addedDate),
      'expDate': Timestamp.fromDate(expDate),
    };
  }

  factory Product.fromMap(String barcode, Map<String, dynamic> map) {
    return Product(
      barcode: barcode,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      shelfLifeDays: map['shelfLifeDays'] ?? 0,
      addedDate: (map['addedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expDate: (map['expDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}