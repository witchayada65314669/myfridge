import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void toggleObscure(String field) {
    setState(() {
      if (field == 'current') _obscureCurrent = !_obscureCurrent;
      if (field == 'new') _obscureNew = !_obscureNew;
      if (field == 'confirm') _obscureConfirm = !_obscureConfirm;
    });
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception('User not logged in');

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPasswordController.text);

      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully!')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = switch (e.code) {
        'wrong-password' => 'Current password is incorrect',
        'weak-password' => 'New password is too weak',
        _ => e.message ?? 'Failed to change password',
      };
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white),),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildPasswordField(
                          controller: currentPasswordController,
                          label: 'Current password',
                          obscureText: _obscureCurrent,
                          toggle: () => toggleObscure('current'),
                          validator: (val) =>
                              val!.isEmpty ? 'Please enter your current password' : null,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: newPasswordController,
                          label: 'New password',
                          obscureText: _obscureNew,
                          toggle: () => toggleObscure('new'),
                          validator: (val) =>
                              val!.isEmpty ? 'Please enter your new password' : null,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: confirmPasswordController,
                          label: 'Confirm new password',
                          obscureText: _obscureConfirm,
                          toggle: () => toggleObscure('confirm'),
                          validator: (val) =>
                              val != newPasswordController.text ? 'Passwords do not match' : null,
                          theme: theme,
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: Text(
                              'Forgot your password?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80), // extra space to avoid overlap with button
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _changePassword,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Change Password'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback toggle,
    required String? Function(String?) validator,
    required ThemeData theme,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}