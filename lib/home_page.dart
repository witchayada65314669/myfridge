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
import 'package:myfridge_test/emoji.dart';
import 'package:myfridge_test/add_item_page.dart';
import 'package:myfridge_test/notification_service.dart';

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
  bool _isShowingNotification = false;

  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Meat', 'Vegetable', 'Fruit', 'Seafood'];

  List<AppNotification> _notifications = [];

  Stream<QuerySnapshot> _getUserFoodStream() {
    if (_currentUser == null) return const Stream.empty();
    return _firestore
        .collection('Fridge')
        .where('userId', isEqualTo: _currentUser!.uid)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _scheduleDailyReminder();
  }

  Future<void> _scheduleDailyReminder() async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('Fridge')
        .where('userId', isEqualTo: _currentUser?.uid)
        .get();

    final items = snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
    final expiring = items.where((i) =>
        i.expirationDate != null &&
        i.expirationDate!.difference(now).inDays <= 2).toList();

    String body;
    if (expiring.isEmpty) {
      body = "วันนี้ไม่มีของที่ใกล้หมดอายุ 🎉";
    } else {
      body = "วันนี้มีของใกล้หมดอายุ ${expiring.length} รายการ เช่น ${expiring.first.name}";
    }

    await NotificationService.scheduleDailyNotification(
        "🧊 สรุปของในตู้เย็นวันนี้", body);
  }

  String _normalizeCategory(String category) {
    final c = category.toLowerCase();
    if (['pork', 'beef', 'chicken', 'meat'].contains(c)) return 'Meat';
    if (['vegetable', 'carrot', 'broccoli'].contains(c)) return 'Vegetable';
    if (['fruit', 'apple', 'banana'].contains(c)) return 'Fruit';
    if (['seafood', 'fish', 'shrimp'].contains(c)) return 'Seafood';
    return 'Other';
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

  int get unreadNotifications => _notifications.length;

  List<AppNotification> _generateNotifications(List<FoodItem> items) {
    final now = DateTime.now();
    return items
        .where((i) =>
            i.expirationDate != null &&
            i.expirationDate!.difference(now).inDays <= 2)
        .map((i) => AppNotification(
              "ใกล้หมดอายุ!",
              "${i.name} จะหมดอายุใน ${i.expirationDate!.difference(now).inDays} วัน",
            ))
        .toList();
  }

  void _showNotifications() {
    if (_isShowingNotification) return;
    _isShowingNotification = true;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    String title;
    String message;

    if (_notifications.isEmpty) {
      title = "🎉 ไม่มีของใกล้หมดอายุ";
      message = "ตู้เย็นของคุณยังสดใหม่อยู่เลย 😋";
    } else {
      final n = _notifications.first;
      final match = RegExp(r'(\d+)').firstMatch(n.message);
      final dayCount = int.tryParse(match?.group(1) ?? "0") ?? 0;

      String emoji;
      if (dayCount == 0) {
        emoji = "⚠️";
      } else if (dayCount == 1) {
        emoji = "⏳";
      } else {
        emoji = "🥦";
      }

      title = "$emoji ${n.title}";
      message = "เหลือเวลาอีก $dayCount วันก่อนหมดอายุ";
    }

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -150, end: 0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: Color(0xFF6F398E), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6F398E))),
                          const SizedBox(height: 2),
                          Text(message,
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
      _isShowingNotification = false;
    });
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
                    child: CircularProgressIndicator(color: Color(0xFF6F398E)),
                  );
                }

                final items =
                    snapshot.data!.docs.map((d) => FoodItem.fromFirestore(d)).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final newNotifications = _generateNotifications(items);
                  if (mounted && newNotifications.length != _notifications.length) {
                    setState(() => _notifications = newNotifications);
                  }
                });

                final filtered = selectedCategory == 'All'
                    ? items
                    : items
                        .where((i) =>
                            _normalizeCategory(i.category) == selectedCategory)
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text("🥶 ไม่มีรายการในหมวดนี้",
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

      /// ✅ ปุ่มเพิ่มข้อมูล (กลับมาแล้ว!)
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
      actions: [_buildNotificationIcon()],
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded,
              color: Color(0xFF6F398E), size: 30),
          onPressed: _showNotifications,
        ),
        if (unreadNotifications > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text(
                '$unreadNotifications',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
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
                  .withOpacity(0.85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  if (item.expirationDate != null)
                    Text(
                      'Exp: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
            if (item.expirationDate != null)
              Text('วันหมดอายุ: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}'),
            if (item.weight != null) Text('น้ำหนัก: ${item.weight} kg'),
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
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.black),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article, color: Colors.white),
              title: const Text('Summary', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SummaryPage(userId: _currentUser!.uid)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SettingPage()));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
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
}

class AppNotification {
  final String title;
  final String message;
  AppNotification(this.title, this.message);
}
