// lib/model/log_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LogService {
  /// เพิ่มของเข้าคอลเลกชัน Fridge และเขียน FridgeLog (eventType=added)
  static Future<void> addFridgeItemAndLog({
    required String userId,
    required String productId,
    required String productName,
    required String
        category, // 'pork' | 'beef' | 'chicken' | 'vegetable' | 'fruit' | 'seafood' | 'meat'
    required double quantityKg, // หน่วยเป็น kg เท่านั้น
    String imageUrl = '',
    DateTime? expiryDate,
  }) async {
    final fs = FirebaseFirestore.instance;

    // 1) เข้าตู้ (Fridge)
    final docRef = await fs.collection('Fridge').add({
      'userId': userId,
      'productId': productId,
      'productName': productName.trim(),
      'category': category.toLowerCase(),
      'quantity': quantityKg, // เก็บเป็น kg
      'unit': 'kg',
      'imageUrl': imageUrl,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) Log (FridgeLog) — summary จะอ่านจากตรงนี้
    await fs.collection('FridgeLog').add({
      'userId': userId,
      'eventType': 'added',
      'eventAt': FieldValue.serverTimestamp(),
      'productId': productId,
      'productName': productName.trim(),
      'category': category.toLowerCase(),
      'quantityKg': quantityKg,
      'source': 'app_add',
      'fridgeDocId': docRef.id,
    });
  }

  /// ใช้กรณี "เพิ่มเข้า Fridge ไปแล้วที่หน้าอื่น" — จะเขียนเฉพาะ Log เพิ่มเติม
  static Future<void> logAddedOnly({
    required String userId,
    required String productId,
    required String productName,
    required String category,
    required double quantityKg,
    String? fridgeDocId,
  }) async {
    final fs = FirebaseFirestore.instance;
    await fs.collection('FridgeLog').add({
      'userId': userId,
      'eventType': 'added',
      'eventAt': FieldValue.serverTimestamp(),
      'productId': productId,
      'productName': productName.trim(),
      'category': category.toLowerCase(),
      'quantityKg': quantityKg,
      'source': 'app_add_onlylog',
      if (fridgeDocId != null) 'fridgeDocId': fridgeDocId,
    });
  }
}
