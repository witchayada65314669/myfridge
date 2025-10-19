import 'package:cloud_firestore/cloud_firestore.dart';

class LogService {
  static Future<void> addFridgeItemAndLog({
    required String userId,
    required String productId,
    required String productName,
    required String
        category, // pork/beef/chicken/vegetable/fruit/seafood/meat/other
    required double quantityKg, // kg เสมอ
    String imageUrl = '',
    DateTime? expiryDate,
  }) async {
    final fs = FirebaseFirestore.instance;

    final docRef = await fs.collection('Fridge').add({
      'userId': userId,
      'productId': productId,
      'productName': productName.trim(),
      'category': category.toLowerCase(),
      'quantity': quantityKg,
      'unit': 'kg',
      'imageUrl': imageUrl,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

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

  // ซ่อมอัตโนมัติ: ถ้าใน Fridge มีเอกสารที่ยังไม่มี Log → สร้าง Log ให้
  static Future<int> ensureFridgeLogForUserRecent(String userId,
      {int limit = 80}) async {
    final fs = FirebaseFirestore.instance;
    final snap = await fs
        .collection('Fridge')
        .where('userId', isEqualTo: userId)
        .orderBy('addedAt', descending: true)
        .limit(limit)
        .get();

    int created = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final unit = (data['unit'] ?? '').toString().toLowerCase();
      if (unit != 'kg') continue;

      final existed = await fs
          .collection('FridgeLog')
          .where('userId', isEqualTo: userId)
          .where('fridgeDocId', isEqualTo: d.id)
          .limit(1)
          .get();
      if (existed.docs.isNotEmpty) continue;

      final q = data['quantity'];
      final qty = (q is num) ? q.toDouble() : double.tryParse('$q') ?? 0.0;
      if (qty <= 0) continue;

      await fs.collection('FridgeLog').add({
        'userId': userId,
        'eventType': 'added',
        'eventAt': data['addedAt'] ?? FieldValue.serverTimestamp(),
        'productId': (data['productId'] ?? '').toString(),
        'productName': (data['productName'] ?? '').toString().trim(),
        'category': (data['category'] ?? 'other').toString().toLowerCase(),
        'quantityKg': qty,
        'source': 'self_heal_from_fridge',
        'fridgeDocId': d.id,
      });
      created++;
    }
    return created;
  }
}
