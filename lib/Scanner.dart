import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ✅ แก้ path ให้ตรงกับที่สร้างไฟล์จริง
import 'package:myfridge_test/log_service.dart';
import 'package:myfridge_test/quantity_converter.dart';

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

  // ✅ ย้ายออกมาที่ระดับคลาส ให้เมธอดอื่นเรียกได้
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String?> _captureAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return null;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance.ref().child(
          'fridge_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('🚨 Error capturing/uploading image: $e');
      return null;
    }
  }

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
        'unit': data['unit'] ?? 'kg', // ✅ ดีฟอลต์ให้เป็น kg
        'brand': data['brand'] ?? '',
      };
    } catch (e) {
      print('🚨 Error getting product: $e');
      return null;
    }
  }

  Future<void> _addToFridge(
      Map<String, dynamic> product, String? imageUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final String unit = (product['unit'] ?? 'kg').toString().toLowerCase();
      const double baseQty = 1.0; // สแกน 1 ชิ้น/แพ็ค = 1 unit
      // ✅ ถ้า unit ไม่รู้จัก จะคืน baseQty (ถือเป็น kg)
      final double qtyKg = QuantityConverter.toKg(baseQty, unit);

      final categoryKey = _mapCategory(product['category']);

      await LogService.addFridgeItemAndLog(
        userId: user.uid,
        productId:
            (product['id'] ?? 'manual_${DateTime.now().millisecondsSinceEpoch}')
                .toString(),
        productName: (product['name'] ?? 'Unknown Product').toString(),
        category: categoryKey,
        quantityKg: qtyKg,
        imageUrl: imageUrl ?? (product['imageUrl'] ?? ''),
        expiryDate:
            DateTime.now().add(Duration(days: product['shelfLife'] ?? 7)),
      );
      print('✅ Added & Logged');
    } catch (e) {
      print('🚨 Error adding to fridge & log: $e');
      rethrow;
    }
  }

  Future<void> _handleBarcodeDetected(String code) async {
    if (_isDialogShown || _isProcessing) return;
    setState(() {
      _isProcessing = true;
      _isDialogShown = true;
    });

    try {
      final product = await _getProductByBarcode(code);
      if (product != null) {
        final imageUrl = await _captureAndUploadImage();
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
                  width: scanAreaSize, height: 2, color: Colors.greenAccent),
            );
          },
        ),
        const Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Text(
            'วางบาร์โค้ดหรือ QR Code ภายในกรอบ',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
