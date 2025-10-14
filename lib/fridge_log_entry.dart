// lib/fridge_log_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum FoodCategory {
  pork,
  beef,
  chicken,
  vegetable,
  fruit,
  seafood,
  meat,
  other
}

enum LogEventType { added, removed, adjusted }

class FridgeLogEntry {
  final String id;
  final String userId;
  final LogEventType eventType;
  final DateTime eventAt;
  final String productId;
  final String productName;
  final FoodCategory category;
  final double quantityKg;

  FridgeLogEntry({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.eventAt,
    required this.productId,
    required this.productName,
    required this.category,
    required this.quantityKg,
  });

  static FridgeLogEntry fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    SnapshotOptions? _,
  ) {
    final d = doc.data()!;
    final rawEvent = (d['eventType'] ?? 'added').toString().toLowerCase();
    final evt = switch (rawEvent) {
      'added' => LogEventType.added,
      'removed' => LogEventType.removed,
      'adjusted' => LogEventType.adjusted,
      _ => LogEventType.added,
    };

    // รองรับทั้ง quantityKg และ quantity เดิม
    final q = d['quantityKg'] ?? d['quantity'] ?? 0;
    final qty = (q is num) ? q.toDouble() : double.tryParse('$q') ?? 0.0;

    final rawCat = (d['category'] ?? 'other').toString().toLowerCase();
    final cat = switch (rawCat) {
      'pork' => FoodCategory.pork,
      'beef' => FoodCategory.beef,
      'chicken' => FoodCategory.chicken,
      'vegetable' => FoodCategory.vegetable,
      'fruit' => FoodCategory.fruit,
      'seafood' => FoodCategory.seafood,
      'meat' => FoodCategory.meat,
      _ => FoodCategory.other,
    };

    return FridgeLogEntry(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      eventType: evt,
      eventAt: (d['eventAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productId: (d['productId'] ?? '').toString(),
      productName: (d['productName'] ?? '').toString(),
      category: cat,
      quantityKg: qty,
    );
  }

  static Map<String, Object?> toFirestore(FridgeLogEntry e, SetOptions? _) {
    return {
      'userId': e.userId,
      'eventType': e.eventType.name,
      'eventAt': Timestamp.fromDate(e.eventAt),
      'productId': e.productId,
      'productName': e.productName,
      'category': e.category.name,
      'quantityKg': e.quantityKg,
    };
  }
}
