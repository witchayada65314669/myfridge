import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:myfridge_test/log_service.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  String? _selectedCategory;

  // ✅ ตัวเลือกหมวด — ใช้ตามฟอร์มเดิมของคุณ
  final List<String> categories = [
    'Beef',
    'Pork',
    'Chicken',
    'Vegetable',
    'Fruit',
    'Seafood',
    'Other'
  ];

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  /// ✅ map ชื่อใน UI → คีย์ที่ summary รองรับ
  String _mapCategory(String? ui) {
    switch ((ui ?? 'Other').toLowerCase()) {
      case 'beef':
        return 'beef';
      case 'pork':
        return 'pork';
      case 'chicken':
        return 'chicken';
      case 'vegetable':
        return 'vegetable';
      case 'fruit':
        return 'fruit';
      case 'seafood':
        return 'seafood';
      case 'meat':
        return 'meat'; // เผื่ออนาคตมีตัวเลือกนี้
      default:
        return 'other';
    }
  }

  Future<void> _addItem() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isProcessing = true);
      final now = DateTime.now();
      final expirationDate = now.add(const Duration(days: 2));

      final productName = nameController.text.trim();
      final categoryKey = _mapCategory(_selectedCategory);
      final qtyKg = double.tryParse(quantityController.text.trim()) ?? 1.0;

      // 1) ✅ เพิ่มข้อมูลลง Fridge (ฟิลด์ให้ตรงมาตรฐาน: addedAt / expiryDate)
      final docRef = await FirebaseFirestore.instance.collection('Fridge').add({
        'userId': user.uid,
        'productId': 'manual_${now.millisecondsSinceEpoch}',
        'productName': productName,
        'barcode': '',
        'category': _selectedCategory ??
            'Other', // เก็บชื่อ UI ได้ตามเดิม (หน้า Home ใช้อยู่)
        'quantity': qtyKg, // เก็บเป็น kg ตามดีไซน์ใหม่
        'unit': 'kg',
        'imageUrl': '',
        'addedAt': now, // ถ้าอยากใช้ server time: FieldValue.serverTimestamp()
        'expiryDate': expirationDate,
        'updatedAt': now,
      });

      // 2) ✅ ถ่ายรูปสินค้า (optional — เหมือนหน้า Scanner)
      String imageUrl = '';
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final imageFile = File(photo.path);
        final ref = _storage.ref().child(
            'Fridge/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
        await docRef.update({'imageUrl': imageUrl});
      }

      // 3) ✅ เขียน Log สำหรับ Summary (อ่านจาก FridgeLog)
      await LogService.logAddedOnly(
        userId: user.uid,
        productId: 'manual_${now.millisecondsSinceEpoch}',
        productName: productName,
        category: categoryKey, // ใช้ key ที่ summary รองรับ
        quantityKg: qtyKg,
        fridgeDocId:
            docRef.id, // ผูกกลับเอกสารใน Fridge (กันซ้ำ/ซ่อมย้อนหลังได้)
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ เพิ่มข้อมูลและถ่ายรูปเรียบร้อยแล้ว!'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true);
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⏱️ การเชื่อมต่อ Firebase ใช้เวลานานเกินไป'),
        backgroundColor: Colors.orange,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ เกิดข้อผิดพลาด: $e'),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expirationDate = now.add(const Duration(days: 2));

    return Scaffold(
      backgroundColor: const Color(0xFFCACBE7),
      appBar: AppBar(
        title: const Text(
          'เพิ่มรายการอาหาร',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6F398E),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Icon(Icons.fastfood,
                          color: Color(0xFF6F398E), size: 70),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.restaurant_menu,
                              color: Colors.deepPurple),
                          labelText: 'ชื่ออาหาร',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'กรุณากรอกชื่ออาหาร'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.category,
                              color: Colors.deepPurple),
                          labelText: 'เลือกหมวดหมู่',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        items: categories
                            .map((cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        validator: (v) =>
                            v == null ? 'กรุณาเลือกหมวดหมู่' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.scale, color: Colors.deepPurple),
                          labelText: 'น้ำหนัก (kg)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null || d <= 0)
                            return 'กรุณากรอกน้ำหนักมากกว่า 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      _infoRow(Icons.calendar_today, 'เพิ่มเมื่อ',
                          DateFormat('dd/MM/yyyy HH:mm').format(now)),
                      const SizedBox(height: 10),
                      _infoRow(
                          Icons.timer,
                          'หมดอายุโดยประมาณ',
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(expirationDate)),
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6F398E),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _addItem,
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.white),
                          label: const Text('เพิ่มรายการและถ่ายรูป',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "กำลังบันทึกและอัปโหลดรูป...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6F398E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    super.dispose();
  }
}
