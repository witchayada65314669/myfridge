import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with SingleTickerProviderStateMixin {
  bool _isDialogShown = false;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 📸 ถ่ายรูปและอัปโหลดไปยัง Firebase Storage
  Future<String?> _captureAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) return null;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('fridge_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();
      print('📸 Uploaded image URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('🚨 Error capturing/uploading image: $e');
      return null;
    }
  }

  /// 🔍 ค้นหาสินค้าจากบาร์โค้ด
  Future<Map<String, dynamic>?> _getProductByBarcode(String barcode) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();

      return {
        'id': doc.id,
        'barcode': data['barcode']?.toString() ?? '',
        'name': data['name'] ?? 'Unknown Product',
        'category': data['category'] ?? 'Other',
        'shelfLife': data['shelfLife'] ?? 7,
        'imageUrl': data['imageUrl'] ?? '',
        'unit': data['unit'] ?? 'ชิ้น',
        'brand': data['brand'] ?? '',
      };
    } catch (e) {
      print('🚨 Error getting product: $e');
      return null;
    }
  }

  /// 🧊 เพิ่มสินค้าเข้าตู้เย็น (รวม URL ของรูป)
  Future<void> _addToFridge(Map<String, dynamic> product, String? imageUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final existing = await FirebaseFirestore.instance
          .collection('Fridge')
          .where('userId', isEqualTo: user.uid)
          .where('productId', isEqualTo: product['id'])
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Fridge')
            .doc(existing.docs.first.id)
            .update({
          'quantity': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('📈 Updated existing product quantity');
      } else {
        await FirebaseFirestore.instance.collection('Fridge').add({
          'userId': user.uid,
          'productId': product['id'],
          'productName': product['name'],
          'barcode': product['barcode'],
          'category': product['category'],
          'quantity': 1,
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expiryDate': DateTime.now()
              .add(Duration(days: product['shelfLife'] ?? 7))
              .toIso8601String(),
          'imageUrl': imageUrl ?? product['imageUrl'], // ✅ ใช้รูปใหม่ ถ้าไม่มีใช้ของเดิม
          'unit': product['unit'],
          'brand': product['brand'],
        });
        print('✅ Added new product to fridge');
      }
    } catch (e) {
      print('🚨 Error adding to fridge: $e');
    }
  }

  Future<void> _handleBarcodeDetected(String code) async {
    if (_isDialogShown || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isDialogShown = true;
    });

    try {
      print('🎯 Detected barcode: $code');

      final product = await _getProductByBarcode(code);

      if (product != null) {
        final imageUrl = await _captureAndUploadImage(); // 📸 ถ่ายและอัปโหลด
        await _addToFridge(product, imageUrl);

        if (!mounted) return;
        _showSuccessDialog(product['name']);
      } else {
        if (!mounted) return;
        _showProductNotFoundDialog(code);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e);
    }
  }

  /// ✅ Dialog สแกนสำเร็จ
  void _showSuccessDialog(String productName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('สแกนสำเร็จ 🎉'),
        content: Text('เพิ่ม "$productName" ลงในตู้เย็นเรียบร้อยแล้ว'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isDialogShown = false;
                _isProcessing = false;
              });
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  /// ⚠️ Dialog ไม่พบสินค้า
  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ไม่พบสินค้า'),
        content: Text('ไม่พบข้อมูลสินค้าสำหรับบาร์โค้ด: $barcode'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isDialogShown = false;
                _isProcessing = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  /// ❌ Dialog Error
  void _showErrorDialog(dynamic error) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('เกิดข้อผิดพลาด'),
        content: Text('ไม่สามารถเพิ่มสินค้าได้: $error'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isDialogShown = false;
                _isProcessing = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  /// 📷 UI สแกน
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const scanAreaSize = 250.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกน QR / Barcode'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null && !_isDialogShown) {
                  _handleBarcodeDetected(code);
                  break;
                }
              }
            },
          ),
          _buildScannerOverlay(size, scanAreaSize),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// 🎞️ แอนิเมชันกรอบสแกน
  Widget _buildScannerOverlay(Size size, double scanAreaSize) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              top: size.height * 0.5 -
                  scanAreaSize / 2 +
                  (scanAreaSize * _animation.value),
              left: size.width * 0.5 - scanAreaSize / 2,
              child: Container(
                width: scanAreaSize,
                height: 2,
                color: Colors.greenAccent,
              ),
            );
          },
        ),
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: const Text(
            'วางบาร์โค้ดหรือ QR Code ภายในกรอบ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
