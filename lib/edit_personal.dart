import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditPersonalPage extends StatefulWidget {
  const EditPersonalPage({super.key});

  @override
  State<EditPersonalPage> createState() => _EditPersonalPageState();
}

class _EditPersonalPageState extends State<EditPersonalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      _photoUrl = user.photoURL;

      // 🔹 ดึงรูปจาก Firestore เผื่อมีเก็บไว้
      final userDoc =
          await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('photoUrl')) {
        setState(() {
          _photoUrl = userDoc['photoUrl'];
        });
      }
    }
  }

  /// 🔹 เลือกรูปจากแกลเลอรี
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  /// 🔹 ถ่ายภาพจากกล้อง
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCACBE7),
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF6F398E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildProfileImage(),
              const SizedBox(height: 25),

              // 🔹 ช่องชื่อ
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 20),

              // 🔹 ช่องอีเมล
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6F398E),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _updateDetails,
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 ส่วนของรูปโปรไฟล์
  Widget _buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.white,
          backgroundImage: _selectedImage != null
              ? FileImage(_selectedImage!)
              : (_photoUrl != null
                  ? NetworkImage(_photoUrl!)
                  : null) as ImageProvider?,
          child: _photoUrl == null && _selectedImage == null
              ? const Icon(Icons.person, size: 60, color: Colors.grey)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: PopupMenuButton<String>(
            icon: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF6F398E),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
            ),
            onSelected: (value) {
              if (value == 'camera') {
                _takePhoto();
              } else {
                _pickImage();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'camera',
                child: Text('ถ่ายรูปใหม่'),
              ),
              const PopupMenuItem(
                value: 'gallery',
                child: Text('เลือกรูปจากแกลเลอรี'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 🔹 ฟังก์ชันอัปเดตข้อมูล
  Future<void> _updateDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? uploadedUrl = _photoUrl;

      // ✅ ถ้ามีรูปใหม่ → อัปโหลดไป Firebase Storage
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        uploadedUrl = await ref.getDownloadURL();
      }

      // ✅ อัปเดตข้อมูลใน Firebase Auth
      await user.updateDisplayName(_nameController.text);
      if (uploadedUrl != null) await user.updatePhotoURL(uploadedUrl);

      // ✅ อัปเดต Firestore
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
        'name': _nameController.text,
        'email': _emailController.text,
        'photoUrl': uploadedUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ อัปเดตอีเมล (ถ้าเปลี่ยน)
      if (user.email != _emailController.text) {
        await user.verifyBeforeUpdateEmail(_emailController.text);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
