import 'package:cloud_firestore/cloud_firestore.dart';

enum FoodCategory {
  pork,
  beef,
  chicken,
  meat,
  vegetable,
  fruit,
  seafood,
  other
}

enum LogEvent { added, removed }

FoodCategory _catFromString(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'pork':
      return FoodCategory.pork;
    case 'beef':
      return FoodCategory.beef;
    case 'chicken':
      return FoodCategory.chicken;
    case 'meat':
      return FoodCategory.meat;
    case 'vegetable':
    case 'veggie':
      return FoodCategory.vegetable;
    case 'fruit':
    case 'fruits':
      return FoodCategory.fruit;
    case 'seafood':
      return FoodCategory.seafood;
    default:
      return FoodCategory.other;
  }
}

String _catToString(FoodCategory c) => c.name;

LogEvent _eventFromString(String? v) =>
    (v?.toLowerCase() == 'removed') ? LogEvent.removed : LogEvent.added;
String _eventToString(LogEvent e) => e.name;

class FridgeLogEntry {
  final String id; // doc id
  final String userId;
  final String productName;
  final FoodCategory category;
  final double quantityKg; // kg เสมอ
  final LogEvent eventType; // added / removed
  final DateTime eventAt;
  final String? sourceId; // อ้างอิง doc ใน Fridge (ถ้ามี)

  FridgeLogEntry({
    required this.id,
    required this.userId,
    required this.productName,
    required this.category,
    required this.quantityKg,
    required this.eventType,
    required this.eventAt,
    this.sourceId,
  });

  // Firestore converter
  static FridgeLogEntry fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snap, SnapshotOptions? _) {
    final d = snap.data()!;
    return FridgeLogEntry(
      id: snap.id,
      userId: d['userId'] as String,
      productName: (d['productName'] ?? d['name'] ?? 'item') as String,
      category: _catFromString(d['category'] as String?),
      quantityKg: (d['quantityKg'] ?? d['quantity'] ?? 0).toDouble(),
      eventType: _eventFromString(d['eventType'] as String?),
      eventAt: (d['eventAt'] as Timestamp).toDate(),
      sourceId: d['sourceId'] as String?,
    );
  }

  static Map<String, Object?> toFirestore(FridgeLogEntry e, SetOptions? _) {
    return {
      'userId': e.userId,
      'productName': e.productName,
      'category': _catToString(e.category),
      'quantityKg': e.quantityKg,
      'eventType': _eventToString(e.eventType),
      'eventAt': Timestamp.fromDate(e.eventAt),
      'sourceId': e.sourceId,
    };
  }
}
