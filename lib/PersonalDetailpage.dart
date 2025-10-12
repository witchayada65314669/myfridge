import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class PersonalDetailsBottomSheet extends StatefulWidget {
  const PersonalDetailsBottomSheet({super.key});

  @override
  State<PersonalDetailsBottomSheet> createState() =>
      _PersonalDetailsBottomSheetState();
}

class _PersonalDetailsBottomSheetState
    extends State<PersonalDetailsBottomSheet> {
  final User? _user = FirebaseAuth.instance.currentUser;
  File? _imageFile;
  bool _isUpdating = false;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _isEmailVerified = _user?.emailVerified ?? false;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await _updateProfilePicture();
    }
  }

  Future<void> _updateProfilePicture() async {
    if (_user == null || _imageFile == null) return;

    setState(() => _isUpdating = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${_user!.uid}.jpg');

      await ref.putFile(_imageFile!);
      final downloadUrl = await ref.getDownloadURL();

      await _user.updatePhotoURL(downloadUrl);
      await _user.reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile picture updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateDisplayName(String newName) async {
    if (_user == null || newName.isEmpty) return;

    setState(() => _isUpdating = true);

    try {
      await _user.updateDisplayName(newName);
      await _user.reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Display name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to update name: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _verifyEmail() async {
    if (_user == null || _isEmailVerified) return;

    try {
      await _user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📨 Verification email sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to send verification: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth * 0.85;

        return Stack(
          children: [
            _buildHandle(constraints),
            Positioned(
              top: 60,
              left: 22,
              right: 22,
              bottom: 0,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: theme.colorScheme.primary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Personal Details',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildAvatar(),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _isUpdating ? null : _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: _isUpdating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildEditableInfoCard(
                      context,
                      title: 'Name',
                      initialValue: _user?.displayName ?? 'Not provided',
                      icon: Icons.person_outline,
                      width: fieldWidth,
                      onSubmitted: _updateDisplayName,
                    ),
                    _buildInfoCard(
                      context,
                      title: 'Email',
                      content: _user?.email ?? 'No email',
                      icon: Icons.email_outlined,
                      width: fieldWidth,
                      isVerified: _isEmailVerified,
                      onVerify: _verifyEmail,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 28,
                        top: 12,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isUpdating
                              ? null
                              : () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 6,
                            shadowColor:
                                theme.colorScheme.primary.withValues(alpha: 0.4),
                          ),
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHandle(BoxConstraints constraints) {
    return Positioned(
      top: 12,
      left: (constraints.maxWidth - 40) / 2,
      child: Container(
        height: 5,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade500,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!)
                  : (_user?.photoURL != null
                      ? CachedNetworkImageProvider(_user!.photoURL!)
                          as ImageProvider
                      : null),
              child: _user?.photoURL == null && _imageFile == null
                  ? Icon(Icons.person, size: 50, color: Colors.grey.shade600)
                  : null,
            ),
          ),
          if (_isUpdating)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    required double width,
    bool isVerified = false,
    VoidCallback? onVerify,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (isVerified && title == 'Email') ...[
                        const SizedBox(width: 8),
                        Icon(Icons.verified,
                            size: 16, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!isVerified && title == 'Email' && onVerify != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: onVerify,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Verify Email',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableInfoCard(
    BuildContext context, {
    required String title,
    required String initialValue,
    required IconData icon,
    required double width,
    required Function(String) onSubmitted,
  }) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: initialValue);

    return Center(
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, size: 18),
                          onPressed: () => onSubmitted(controller.text),
                        ),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
