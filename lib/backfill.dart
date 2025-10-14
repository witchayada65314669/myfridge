import 'package:cloud_firestore/cloud_firestore.dart';

double _toKg(double quantity, String unit, String category) {
  final u = unit.toLowerCase();
  if (u == 'kg' || u == 'กก' || u == 'กิโลกรัม') return quantity;
  const defaults = {
    'pork': 0.5,
    'beef': 0.5,
    'chicken': 0.8,
    'vegetable': 0.25,
    'fruit': 0.20,
    'seafood': 0.30,
  };
  return quantity * (defaults[category.toLowerCase()] ?? 0.25);
}

/// ย้ายข้อมูลเก่าจาก Fridge -> FridgeLog (eventType=added) หนึ่งครั้งพอ
Future<int> backfillFridgeToFridgeLogForUser(String uid) async {
  final db = FirebaseFirestore.instance;
  final fridge =
      await db.collection('Fridge').where('userId', isEqualTo: uid).get();
  int created = 0;

  for (final d in fridge.docs) {
    final data = d.data();
    final sourceId = d.id;

    // กันซ้ำ: ถ้ามี log added ของ sourceId นี้แล้ว ให้ข้าม
    final dup = await db
        .collection('FridgeLog')
        .where('userId', isEqualTo: uid)
        .where('eventType', isEqualTo: 'added')
        .where('sourceId', isEqualTo: sourceId)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) continue;

    final name = (data['productName'] ?? data['name'] ?? 'item').toString();
    final category = (data['category'] ?? 'other').toString();
    final unit = (data['unit'] ?? 'kg').toString();
    final qRaw = data['quantity'];
    final qty =
        (qRaw is num) ? qRaw.toDouble() : double.tryParse('$qRaw') ?? 0.0;
    final qtyKg = _toKg(qty, unit, category);

    final addedAt = data['addedAt'];
    final updatedAt = data['updatedAt'];
    DateTime eventAt = DateTime.now();
    if (addedAt is Timestamp)
      eventAt = addedAt.toDate();
    else if (updatedAt is Timestamp) eventAt = updatedAt.toDate();

    await db.collection('FridgeLog').add({
      'userId': uid,
      'productName': name,
      'category': category.toLowerCase(),
      'quantityKg': qtyKg,
      'eventType': 'added',
      'eventAt': Timestamp.fromDate(eventAt),
      'sourceId': sourceId,
    });

    created++;
  }
  return created;
}
