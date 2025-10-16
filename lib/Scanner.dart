import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  /// ✅ เมื่อสแกนเจอ → ค้นสินค้า → เพิ่มลง Fridge พร้อมวันหมดอายุ
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
      // ✅ ค้นหาสินค้าจากตาราง products
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

      final productData = productSnap.docs.first.data();
      final productName = productData['name'] ?? "Unknown Product";
      final category = productData['category'] ?? "Other";
      final expireDays = productData['expireDays'] ?? 7; // ค่า default 7 วัน

      // ✅ คำนวณวันหมดอายุ
      final DateTime now = DateTime.now();
      final DateTime expirationDate = now.add(Duration(days: expireDays));

      // ✅ ถ่ายรูปสินค้า
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final imageFile = File(photo.path);

      // ✅ อัปโหลดรูปไป Firebase Storage
      final ref = _storage
          .ref()
          .child('Fridge/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      // ✅ เพิ่มข้อมูลลง Fridge
      await _firestore.collection('Fridge').add({
        'userId': user.uid,
        'barcode': barcode,
        'productName': productName,
        'category': category,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'expirationDate': expirationDate, // เพิ่มวันหมดอายุ
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ เพิ่ม $productName สำเร็จ (หมดอายุ: ${expirationDate.toLocal().toString().split(' ')[0]})"),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("❌ เกิดข้อผิดพลาด: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcode = capture.barcodes.first.rawValue ?? "";
              if (!_isProcessing && barcode.isNotEmpty) {
                _handleBarcode(barcode);
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

          // ✅ Loading ระหว่างอัปโหลด
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
                      "กำลังบันทึกข้อมูล...",
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
}
