import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationHistoryPage extends StatelessWidget {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  NotificationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบก่อนดูแจ้งเตือน")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6F398E),
        title: const Text(
          "ของใกล้หมดอายุ",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ), 
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('Fridge')
            .where('userId', isEqualTo: _currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("⚠️ โหลดข้อมูลล้มเหลว"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6F398E)),
            );
          }

          final now = DateTime.now();
          final items = snapshot.data!.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['productName'] ?? "Unknown";
                final expiration = (data['expirationDate'] as Timestamp?)?.toDate();
                return {
                  'name': name,
                  'category': data['category'] ?? 'Other',
                  'imageUrl': data['imageUrl'] ?? '',
                  'expiration': expiration,
                };
              })
              .where((item) =>
                  item['expiration'] != null &&
                  item['expiration'].isAfter(now) &&
                  item['expiration'].difference(now).inDays <= 3)
              .toList();

          if (items.isEmpty) {
            return const Center(
              child: Text(
                "ไม่มีของใกล้หมดอายุ 🎉",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          items.sort((a, b) =>
              (a['expiration'] as DateTime).compareTo(b['expiration'] as DateTime));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final name = item['name'];
              final expiration = item['expiration'] as DateTime;
              final daysLeft = expiration.difference(now).inDays;
              final imageUrl = item['imageUrl'];

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ รูปสินค้า (หรือไอคอนแทน)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.fastfood,
                                  color: Colors.white70, size: 32),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // ✅ ข้อความรายละเอียด
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            daysLeft == 0
                                ? "หมดอายุวันนี้!"
                                : "จะหมดอายุในอีก $daysLeft วัน (${DateFormat('dd/MM/yyyy').format(expiration)})",
                            style: TextStyle(
                              fontSize: 14,
                              color: daysLeft <= 1
                                  ? Colors.redAccent
                                  : const Color(0xFF6F398E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      daysLeft <= 1
                          ? Icons.warning_amber_rounded
                          : Icons.timer_outlined,
                      color:
                          daysLeft <= 1 ? Colors.redAccent : const Color(0xFF6F398E),
                      size: 26,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
