import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  final List<String> categories = [
    'Meat',
    'Vegetable',
    'Fruit',
    'Seafood',
    'Other'
  ];

  Future<void> _addItem() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    try {
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 2));

      await FirebaseFirestore.instance.collection('Fridge').add({
        'userId': user.uid,
        'productId': 'manual_${now.millisecondsSinceEpoch}',
        'productName': nameController.text.trim(),
        'barcode': '',
        'category': _selectedCategory ?? 'Other',
        'quantity':
            double.tryParse(quantityController.text.trim()) ?? 1.0,
        'unit': 'kg',
        'imageUrl': '',
        'addedAt': now,
        'expiryDate': expiryDate,
        'updatedAt': now,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ เพิ่มข้อมูลเรียบร้อยแล้ว!'),
          backgroundColor: Colors.green));

      // ✅ กลับหน้า Home แล้ว refresh
      Navigator.pop(context, true);

    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⏱️ การเชื่อมต่อ Firebase ใช้เวลานานเกินไป'),
        backgroundColor: Colors.orange,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('เกิดข้อผิดพลาด: $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 2));

    return Scaffold(
      backgroundColor: const Color(0xFFCACBE7),
      appBar: AppBar(
        title: const Text(
          'เพิ่มรายการอาหาร',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6F398E),
        elevation: 0,
      ),
      body: Center(
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
                    offset: const Offset(0, 5))
              ]),
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
                    validator: (v) =>
                        v!.isEmpty ? 'กรุณากรอกชื่ออาหาร' : null,
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
                    validator: (v) => v == null ? 'กรุณาเลือกหมวดหมู่' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.scale, color: Colors.deepPurple),
                      labelText: 'น้ำหนัก (kg)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'กรุณากรอกน้ำหนัก' : null,
                  ),
                  const SizedBox(height: 30),
                  _infoRow(Icons.calendar_today, 'เพิ่มเมื่อ',
                      DateFormat('dd/MM/yyyy HH:mm').format(now)),
                  const SizedBox(height: 10),
                  _infoRow(Icons.timer, 'หมดอายุโดยประมาณ',
                      DateFormat('dd/MM/yyyy HH:mm').format(expiry)),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F398E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('เพิ่มรายการ',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border:
            Border.all(color: Colors.deepPurple.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6F398E)),
          const SizedBox(width: 10),
          Expanded(
              child: Text('$label: $value',
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade800))),
        ],
      ),
    );
  }
}
