import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myfridge_test/login_page.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _formError;
  String? _firebaseError;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number';
    if (!value.contains(RegExp(r'[a-zA-Z]'))) return 'Password must contain at least one letter';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _formError = null;
        _firebaseError = null;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        await userCredential.user?.updateDisplayName(_usernameController.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          if (e.code == 'email-already-in-use') {
            _firebaseError = 'This email is already registered.';
          } else if (e.code == 'weak-password') {
            _firebaseError = 'The password is too weak.';
          } else if (e.code == 'invalid-email') {
            _firebaseError = 'Invalid email address.';
          } else {
            _firebaseError = 'An error occurred. Please try again.';
          }
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      setState(() => _formError = 'Please correct all errors');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6F398E),
              Color(0xFFCACBE7),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.1,
            vertical: height * 0.05,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/icon/app_icon.png",
                width: width * 0.4,
                height: width * 0.4,
              ),
              SizedBox(height: height * 0.03),
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: width * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: height * 0.04),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _usernameController,
                      hintText: 'Username',
                      icon: Icons.person,
                    ),
                    SizedBox(height: height * 0.02),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: height * 0.02),
                    _buildPasswordField(
                      controller: _passwordController,
                      hintText: 'Password',
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      onToggle: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    SizedBox(height: height * 0.02),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm Password',
                      obscureText: _obscureConfirmPassword,
                      validator: _validateConfirmPassword,
                      onToggle: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                    if (_formError != null)
                      Padding(
                        padding: EdgeInsets.only(top: height * 0.02),
                        child: Text(
                          _formError!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: width * 0.035,
                          ),
                        ),
                      ),
                    if (_firebaseError != null)
                      Padding(
                        padding: EdgeInsets.only(top: height * 0.02),
                        child: Text(
                          _firebaseError!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: width * 0.035,
                          ),
                        ),
                      ),
                    SizedBox(height: height * 0.04),
                    SizedBox(
                      width: double.infinity,
                      height: height * 0.06,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        onPressed: _isLoading ? null : _createAccount,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFF6F398E),
                              )
                            : Text(
                                'Create Account',
                                style: TextStyle(
                                  color: const Color(0xFF6F398E),
                                  fontSize: width * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: height * 0.03),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginPage()),
                              );
                            },
                      child: Text(
                        'Already have an account? Log in',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: width * 0.04,
                          decoration: TextDecoration.underline,
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF6F398E)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $hintText';
        }
        if (hintText == 'Email' && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required String? Function(String?) validator,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.lock, color: Color(0xFF6F398E)),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFF6F398E),
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
      validator: validator,
    );
  }
}