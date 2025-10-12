import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myfridge_test/product_model.dart';

class ProductService {
  final _db = FirebaseFirestore.instance;

  Future<Product?> getProduct(String barcode) async {
    final doc = await _db.collection('products').doc(barcode).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.id, doc.data()!);
  }

  Future<void> addToFridge(Product product) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('fridge')
        .doc(product.barcode)
        .set(product.toMap());
  }

  Future<List<Product>> getFridgeItems() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('fridge')
        .get();

    return snapshot.docs
        .map((doc) => Product.fromMap(doc.id, doc.data()))
        .toList();
  }
}