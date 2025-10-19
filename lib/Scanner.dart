import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ✅ ปรับ path ให้ตรงตำแหน่งไฟล์จริงของคุณ
import 'package:myfridge_test/log_service.dart';
import 'package:myfridge_test/quantity_converter.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  bool _hasScanned = false;

  /// map หมวดจาก products → key ที่ summary รองรับ
  String _mapCategory(dynamic raw) {
    final c = (raw ?? '').toString().toLowerCase().trim();
    switch (c) {
      case 'pork':
      case 'beef':
      case 'chicken':
        return c;
      case 'vegetable':
      case 'veggie':
        return 'vegetable';
      case 'fruit':
      case 'fruits':
        return 'fruit';
      case 'seafood':
        return 'seafood';
      case 'meat':
        return 'meat';
      default:
        return 'other';
    }
  }

  /// ✅ เมื่อสแกนเจอ → ค้นสินค้า → เพิ่มลง Fridge+FridgeLog ผ่าน LogService
  Future<void> _handleBarcode(String barcode) async {
    if (_isProcessing || _hasScanned) return;
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("❌ กรุณาเข้าสู่ระบบก่อน")));
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      // 1) ค้นสินค้าจากตาราง products
      final productSnap = await _firestore
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (productSnap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ ไม่พบสินค้านี้ในฐานข้อมูล ($barcode)")),
        );
        Navigator.pop(context);
        return;
      }

      final doc = productSnap.docs.first;
      final data = doc.data();

      final String productId   = doc.id; // ใช้ id เอกสารเป็น productId
      final String productName = (data['name'] ?? "Unknown Product").toString();
      final String categoryKey = _mapCategory(data['category']);
      final String unit        = (data['unit'] ?? 'kg').toString().toLowerCase();

      // อายุสินค้าเป็น "จำนวนวัน" (รองรับ expdate หรือ shelfLife)
      final int? expDays = (data['expdate'] is int)
          ? data['expdate'] as int
          : (data['shelfLife'] is int ? data['shelfLife'] as int : null);

      final now = DateTime.now();
      final DateTime expiryDate = expDays != null ? now.add(Duration(days: expDays)) : now.add(const Duration(days: 7));

      // 2) ถ่ายรูป (optional)
      String imageUrl = (data['imageUrl'] ?? '').toString();
      try {
        final photo = await _picker.pickImage(source: ImageSource.camera);
        if (photo != null) {
          final file = File(photo.path);
          final ref = _storage
              .ref()
              .child('Fridge/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(file);
          imageUrl = await ref.getDownloadURL();
        }
      } catch (_) {
        // ข้ามได้ ถ้าไม่อยากบังคับรูป
      }

      // 3) คำนวณปริมาณเป็น kg (ถ้าหน่วยไม่รู้จัก จะถือว่า 1.0 kg)
      const double baseQty = 1.0; // สแกน 1 แพ็ค = 1 unit
      final double qtyKg = QuantityConverter.toKg(baseQty, unit);

      // 4) ✅ บันทึก Fridge + FridgeLog ผ่าน Service เดียว
      await LogService.addFridgeItemAndLog(
        userId: user.uid,
        productId: productId,
        productName: productName,
        category: categoryKey,
        quantityKg: qtyKg,
        imageUrl: imageUrl,
        expiryDate: expiryDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ เพิ่ม $productName สำเร็จ\nหมดอายุ: ${expiryDate.toLocal().toString().split(' ').first}",
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("❌ เกิดข้อผิดพลาด: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final code = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first.rawValue
                  : null;
              if (!_isProcessing && !_hasScanned && code != null && code.isNotEmpty) {
                _handleBarcode(code);
              }
            },
          ),

          // ✅ กรอบโปร่งตรงกลาง
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),

          // ✅ เงารอบกรอบ
          ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ ข้อความด้านล่าง
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.qr_code_scanner, size: 40, color: Colors.white70),
                  SizedBox(height: 10),
                  Text(
                    "กำลังสแกนบาร์โค้ด...",
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

          // ✅ ปุ่มย้อนกลับ
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // ✅ Loading ระหว่างบันทึก
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text("กำลังบันทึกข้อมูล...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
