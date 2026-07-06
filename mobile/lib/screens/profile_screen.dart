import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'account_settings_screen.dart';
import 'notifications_screen.dart';
import 'privacy_security_screen.dart';
import 'about_screen.dart';

class ProfileScreen extends StatelessWidget {
  final bool isGuestMode;
  
  const ProfileScreen({super.key, this.isGuestMode = false});

  @override
  Widget build(BuildContext context) {
    if (isGuestMode) {
      return _buildGuestMode(context);
    }
    
    final authService = Provider.of<AuthService>(context);
    
    if (!authService.isAuthenticated) {
      return _buildNotAuthenticated(context);
    }
    
    final user = authService.user!;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: user.profilePicture != null
                        ? NetworkImage(user.profilePicture!)
                        : null,
                    child: user.profilePicture == null
                        ? Text(
                            user.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 48),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.username,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.role == 'admin' ? Colors.red.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role == 'admin' ? 'Administrator' : 'Member',
                      style: TextStyle(
                        color: user.role == 'admin' ? Colors.red.shade800 : Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Settings Menu
            Card(
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: 'Account Settings',
                    subtitle: 'Edit profile, change password',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.privacy_tip,
                    title: 'Privacy & Security',
                    subtitle: 'Control your privacy settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: 'About Sudanile Kitchen',
                    subtitle: 'Version 1.0.0',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Stats Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('0', 'Recipes\nSaved'),
                    _buildStat('0', 'Reviews\nWritten'),
                    _buildStat('0', 'Recipes\nSubmitted'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sign Out Button
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: () async {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ),
            
            if (authService.isAdmin) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                  title: const Text('Admin Dashboard'),
                  subtitle: const Text('Manage users, recipes, and submissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Admin dashboard coming soon!')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGuestMode(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person_outline, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Guest Mode', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Sign in to access your profile and saved recipes'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Sign In'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Create an Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAuthenticated(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Not Signed In', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Sign in to access your profile and saved recipes'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
