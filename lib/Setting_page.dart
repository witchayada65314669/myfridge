import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'changepass_page.dart';
import 'PersonalDetailpage.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF6F398E);
  static const Color redColor = Color.fromRGBO(239, 83, 80, 1);
  static const Color greyColor = Colors.black54;
  static const Color lightGreyColor = Color(0xFFF5F5F5);
}

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool isDarkMode = false;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Profile Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            color: AppColors.primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                  child:
                      user?.photoURL == null
                          ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.black54,
                          )
                          : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? "User",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? "No Email",
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.greyColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Settings List
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildSettingsItem(
                        icon: Icons.person,
                        title: 'Edit Personal Details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => const PersonalDetailsBottomSheet(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.lock,
                        title: 'Change Password',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Logout at the very bottom
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: _buildSettingsItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    color: Colors.red,
                    onTap: _showLogoutConfirmation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Color color = Colors.black,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      trailing:
          color != Colors.red
              ? const Icon(Icons.arrow_forward_ios, size: 16)
              : null,
      onTap: onTap,
    );
  }
}
