import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myfridge_test/food_item.dart';
import 'package:myfridge_test/scanner.dart';
import 'package:myfridge_test/Summary_page.dart';
import 'package:myfridge_test/setting_page.dart';
import 'package:myfridge_test/login_page.dart';
import 'package:myfridge_test/add_item_page.dart';
import 'package:myfridge_test/notification_service.dart';
import 'package:myfridge_test/notification_history_page.dart';

class HomePage extends StatefulWidget {
  final String? usersName;
  final String? usersEmail;

  const HomePage({super.key, this.usersName, this.usersEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Meat', 'Vegetable', 'Fruit', 'Seafood'];

  String? _profileImageUrl; // ✅ เก็บลิงก์โปรไฟล์

  @override
  void initState() {
    super.initState();
    _loadProfileImage(); // ✅ โหลดรูปโปรไฟล์
    _scheduleDailyReminder();
    _checkExpiringSoon();
  }

  /// ✅ โหลดรูปโปรไฟล์จาก Firestore
  Future<void> _loadProfileImage() async {
    if (_currentUser == null) return;
    try {
      final doc =
          await _firestore.collection('Users').doc(_currentUser!.uid).get();
      if (doc.exists && doc.data()!.containsKey('photoUrl')) {
        setState(() => _profileImageUrl = doc['photoUrl']);
      } else if (_currentUser!.photoURL != null) {
        setState(() => _profileImageUrl = _currentUser!.photoURL);
      }
    } catch (e) {
      debugPrint('โหลดรูปโปรไฟล์ผิดพลาด: $e');
    }
  }

  /// ✅ แจ้งเตือนประจำวัน
  Future<void> _scheduleDailyReminder() async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('Fridge')
        .where('userId', isEqualTo: _currentUser?.uid)
        .get();

    final items = snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
    final expiringSoon = items
        .where((i) =>
            i.expirationDate != null &&
            i.expirationDate!.isAfter(now) &&
            i.expirationDate!.difference(now).inDays <= 3)
        .toList();

    String body;
    if (expiringSoon.isEmpty) {
      body = "ไม่มีของที่ใกล้หมดอายุ 🎉";
    } else {
      final names = expiringSoon.map((e) => e.name).take(3).join(", ");
      body =
          "มีของใกล้หมดอายุ ${expiringSoon.length} รายการ เช่น $names (${expiringSoon.first.expirationDate != null ? DateFormat('dd/MM').format(expiringSoon.first.expirationDate!) : ''})";
    }

    await NotificationService.scheduleDailyNotification(
      "🧊 ของใกล้หมดอายุ",
      body,
    );
  }

  /// ✅ Popup แจ้งเตือนทันทีถ้ามีของหมดอายุใน 1 วัน
  Future<void> _checkExpiringSoon() async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('Fridge')
        .where('userId', isEqualTo: _currentUser?.uid)
        .get();

    final items = snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
    final expiringSoon = items
        .where((i) =>
            i.expirationDate != null &&
            i.expirationDate!.isAfter(now) &&
            i.expirationDate!.difference(now).inDays <= 1)
        .toList();

    if (expiringSoon.isNotEmpty && mounted) {
      final names = expiringSoon.map((e) => e.name).take(3).join(", ");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("⏰ ของใกล้หมดอายุ",
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              "พบ ${expiringSoon.length} รายการ เช่น $names\nกรุณาเช็คตู้เย็นของคุณก่อนหมดอายุ!",
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ปิด", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationHistoryPage()),
                  );
                },
                child: const Text("ดูทั้งหมด",
                    style: TextStyle(color: Color(0xFF6F398E))),
              ),
            ],
          ),
        );
      });
    }
  }

  Stream<QuerySnapshot> _getUserFoodStream() {
    if (_currentUser == null) return const Stream.empty();
    return _firestore
        .collection('Fridge')
        .where('userId', isEqualTo: _currentUser!.uid)
        .snapshots();
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'meat':
        return const Color(0xFFE53935);
      case 'vegetable':
        return const Color(0xFF43A047);
      case 'fruit':
        return const Color(0xFFFFA726);
      case 'seafood':
        return const Color(0xFF1E88E5);
      default:
        return Colors.grey;
    }
  }

  String _normalizeCategory(String category) {
    final c = category.toLowerCase();
    if (['pork', 'beef', 'chicken', 'meat'].contains(c)) return 'Meat';
    if (['vegetable', 'carrot', 'broccoli'].contains(c)) return 'Vegetable';
    if (['fruit', 'apple', 'banana'].contains(c)) return 'Fruit';
    if (['seafood', 'fish', 'shrimp'].contains(c)) return 'Seafood';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบก่อนใช้งาน")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildAppBar(),
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUserFoodStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("⚠️ โหลดข้อมูลล้มเหลว"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6F398E)));
                }

                final items =
                    snapshot.data!.docs.map((d) => FoodItem.fromFirestore(d)).toList();

                final filtered = selectedCategory == 'All'
                    ? items
                    : items
                        .where((i) =>
                            _normalizeCategory(i.category) == selectedCategory)
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text("ยังไม่มีอาหารในตู้เย็น",
                          style: TextStyle(fontSize: 16)));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, index) => _buildFoodCard(filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6F398E),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _buildAddOptions(),
          );
        },
      ),
    );
  }

  /// ✅ AppBar + ปุ่มแจ้งเตือน
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
      title: const Text(
        "Your Fridge",
        style: TextStyle(
          color: Color(0xFF6F398E),
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF6F398E)),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded,
              color: Color(0xFF6F398E), size: 30),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationHistoryPage()),
            );
          },
        ),
      ],
    );
  }

  /// ✅ Drawer แสดงชื่อ อีเมล และรูปโปรไฟล์
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6F398E), Color(0xFFCACBE7)],
            begin: Alignment.topRight,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              accountName: Text(_currentUser?.displayName ?? "User"),
              accountEmail: Text(_currentUser?.email ?? "No Email"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? const Icon(Icons.person, color: Colors.black, size: 40)
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article, color: Colors.white),
              title: const Text('Summary', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SummaryPage(userId: _currentUser!.uid)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingPage()));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title:
                  const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedCategory == cat;
          final color = _getCategoryColor(cat);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.bold),
              ),
              selected: isSelected,
              selectedColor: color,
              backgroundColor: Colors.grey.shade200,
              onSelected: (_) => setState(() => selectedCategory = cat),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFoodCard(FoodItem item) {
    return GestureDetector(
      onTap: () => _showItemDetails(item),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : Container(color: Colors.white),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: _getCategoryColor(_normalizeCategory(item.category))
                  .withValues(alpha: 0.85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  if (item.addedDate != null)
                    Text(
                      'Added: ${DateFormat('dd/MM/yyyy').format(item.addedDate!)}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  if (item.expirationDate != null)
                    Text(
                      'Exp: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOptions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF6F398E)),
            title: const Text('เพิ่มด้วยการสแกนบาร์โค้ด'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF6F398E)),
            title: const Text('เพิ่มด้วยการกรอกข้อมูลเอง'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddItemPage()));
            },
          ),
        ],
      ),
    );
  }

  void _showItemDetails(FoodItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('หมวดหมู่: ${_normalizeCategory(item.category)}'),
            if (item.addedDate != null)
              Text('วันที่เพิ่ม: ${DateFormat('dd/MM/yyyy').format(item.addedDate!)}'),
            if (item.expirationDate != null)
              Text('วันหมดอายุ: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _firestore.collection('Fridge').doc(item.id).delete();
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
