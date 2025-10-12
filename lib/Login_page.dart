import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'create_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    _prefs = await SharedPreferences.getInstance();
    final remember = _prefs.getBool('rememberMe') ?? false;
    if (remember) {
      final email = await _secureStorage.read(key: 'email');
      final password = await _secureStorage.read(key: 'password');
      setState(() {
        _rememberMe = true;
        _emailController.text = email ?? '';
        _passwordController.text = password ?? '';
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (_rememberMe) {
        await _secureStorage.write(key: 'email', value: _emailController.text.trim());
        await _secureStorage.write(key: 'password', value: _passwordController.text.trim());
        await _prefs.setBool('rememberMe', true);
      } else {
        await _secureStorage.delete(key: 'email');
        await _secureStorage.delete(key: 'password');
        await _prefs.setBool('rememberMe', false);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        case 'user-disabled':
          message = 'บัญชีผู้ใช้นี้ถูกระงับ';
          break;
        case 'user-not-found':
          message = 'ไม่พบผู้ใช้งานอีเมลนี้';
          break;
        case 'wrong-password':
          message = 'รหัสผ่านไม่ถูกต้อง';
          break;
        default:
          message = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
      }
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6F398E), Color(0xFFCACBE7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.08,
              vertical: height * 0.08,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/icon/app_icon.png', width: width * 0.5),
                SizedBox(height: height * 0.04),
                const Text(
                  'Log in',
                  style: TextStyle(
                    fontSize: 32,
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
                        controller: _emailController,
                        hintText: 'Email',
                        icon: Icons.email,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกอีเมล';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(value)) {
                            return 'รูปแบบอีเมลไม่ถูกต้อง';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: height * 0.02),
                      _buildTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        icon: Icons.lock,
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกรหัสผ่าน';
                          }
                          if (value.length < 6) {
                            return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                          }
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (val) => setState(() => _rememberMe = val ?? false),
                            checkColor: Colors.white,
                            activeColor: const Color(0xFF6F398E),
                          ),
                          const Text('Remember Me', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(height: height * 0.02),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Color(0xFF6F398E))
                              : const Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: Color(0xFF6F398E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: height * 0.02),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreatePage()),
                                );
                              },
                        child: const Text(
                          "Don't have an account? Sign up",
                          style: TextStyle(
                            color: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white24,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
