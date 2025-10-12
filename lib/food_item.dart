import 'package:cloud_firestore/cloud_firestore.dart';

class FoodItem {
  final String id;
  final String name;
  final String category;
  final DateTime? expirationDate;
  final DateTime? addedDate;
  final double? weight;
  final String? imageUrl;
  final String userId;

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.userId,
    this.imageUrl,
    this.expirationDate,
    this.addedDate,
    this.weight,
  });

  factory FoodItem.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      final name = data['productName']?.toString() ?? 'Unnamed';
      final category = data['category']?.toString() ?? 'Other';
      final userId = data['userId']?.toString() ?? '';

      return FoodItem(
        id: doc.id,
        name: name,
        category: category,
        userId: userId,
        imageUrl: data['imageUrl']?.toString(),
        expirationDate: _parseDate(data['expiryDate']),
        addedDate: _parseDate(data['addedAt']),
        weight: data['quantity'] != null
            ? double.tryParse(data['quantity'].toString())
            : null,
      );
    } catch (e) {
      print("Error parsing FoodItem: $e");
      return FoodItem(
        id: '',
        name: 'Unnamed',
        category: 'Other',
        userId: '',
      );
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}