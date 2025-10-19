import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FoodItem {
  final String id;
  final String name;
  final String category;
  final DateTime? expirationDate; // ใช้ใน Home
  final DateTime? addedDate; // ใช้ใน Home
  final double? weight; // kg
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
      final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

      // ชื่อสินค้า: productName → name
      final String name = ((data['productName'] ?? data['name']) ?? 'Unnamed')
          .toString()
          .trim();

      // หมวดหมู่
      final String category = (data['category'] ?? 'Other').toString();

      // ผู้ใช้
      final String userId = (data['userId'] ?? '').toString();

      // รูปภาพ (ต้องกัน null ก่อนค่อยเช็ค isEmpty)
      final String? imageUrlRaw = data['imageUrl'] as String?;
      final String? imageUrl =
          (imageUrlRaw == null || imageUrlRaw.isEmpty) ? null : imageUrlRaw;

      // วันที่เพิ่ม: addedAt (ใหม่) หรือ createdAt (เก่า)
      final DateTime? addedDate =
          _toDateTime(data['addedAt']) ?? _toDateTime(data['createdAt']);

      // วันหมดอายุ: expiryDate (ใหม่) หรือ expirationDate (เก่า)
      final DateTime? expirationDate = _toDateTime(data['expiryDate']) ??
          _toDateTime(data['expirationDate']);

      // ปริมาณ/น้ำหนัก (เก็บเป็น kg)
      double? weightKg;
      final dynamic qtyRaw = data['quantity'];
      if (qtyRaw != null) {
        final double? qty =
            (qtyRaw is num) ? qtyRaw.toDouble() : double.tryParse('$qtyRaw');

        if (qty != null) {
          final String unit =
              (data['unit'] ?? 'kg').toString().toLowerCase().trim();
          if (unit == 'g' || unit == 'gram' || unit == 'grams') {
            weightKg = qty / 1000.0;
          } else {
            // default → kg
            weightKg = qty;
          }
        }
      }

      return FoodItem(
        id: doc.id,
        name: name.isEmpty ? 'Unnamed' : name,
        category: category.isEmpty ? 'Other' : category,
        userId: userId,
        imageUrl: imageUrl,
        expirationDate: expirationDate,
        addedDate: addedDate,
        weight: weightKg,
      );
    } catch (e, st) {
      debugPrint("⚠️ Error parsing FoodItem(${doc.id}): $e\n$st");
      return FoodItem(
        id: doc.id,
        name: 'Unnamed',
        category: 'Other',
        userId: '',
      );
    }
  }

  /// helper: แปลงอะไรก็ตามให้เป็น DateTime ถ้าได้
  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.tryParse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
