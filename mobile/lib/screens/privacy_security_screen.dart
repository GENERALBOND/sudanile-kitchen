import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _biometricLogin = false;
  bool _twoFactorAuth = false;
  bool _shareAnalytics = true;
  bool _sharePersonalizedData = true;
  String _selectedPrivacyLevel = 'medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricLogin = prefs.getBool('biometric_login') ?? false;
      _twoFactorAuth = prefs.getBool('two_factor_auth') ?? false;
      _shareAnalytics = prefs.getBool('share_analytics') ?? true;
      _sharePersonalizedData = prefs.getBool('share_personalized_data') ?? true;
      _selectedPrivacyLevel = prefs.getString('privacy_level') ?? 'medium';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_login', _biometricLogin);
    await prefs.setBool('two_factor_auth', _twoFactorAuth);
    await prefs.setBool('share_analytics', _shareAnalytics);
    await prefs.setBool('share_personalized_data', _sharePersonalizedData);
    await prefs.setString('privacy_level', _selectedPrivacyLevel);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy settings saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // Security Section
            _buildSectionHeader('Security', Icons.security),
            _buildSwitchTile(
              icon: Icons.fingerprint,
              title: 'Biometric Login',
              subtitle: 'Use fingerprint or face recognition to login',
              value: _biometricLogin,
              onChanged: (val) => setState(() => _biometricLogin = val),
            ),
            _buildSwitchTile(
              icon: Icons.verified_user,
              title: 'Two-Factor Authentication',
              subtitle: 'Add an extra layer of security to your account',
              value: _twoFactorAuth,
              onChanged: (val) => setState(() => _twoFactorAuth = val),
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Privacy Section
            _buildSectionHeader('Privacy', Icons.privacy_tip),
            _buildSwitchTile(
              icon: Icons.analytics,
              title: 'Share Analytics',
              subtitle: 'Help us improve by sharing anonymous usage data',
              value: _shareAnalytics,
              onChanged: (val) => setState(() => _shareAnalytics = val),
            ),
            _buildSwitchTile(
              icon: Icons.person_search,
              title: 'Personalized Recommendations',
              subtitle: 'Allow us to personalize recipe recommendations',
              value: _sharePersonalizedData,
              onChanged: (val) => setState(() => _sharePersonalizedData = val),
            ),
            
            const SizedBox(height: 16),
            
            // Privacy Level
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Level',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'low', label: Text('Low'), icon: Icon(Icons.public)),
                      ButtonSegment(value: 'medium', label: Text('Medium'), icon: Icon(Icons.people)),
                      ButtonSegment(value: 'high', label: Text('High'), icon: Icon(Icons.lock)),
                    ],
                    selected: {_selectedPrivacyLevel},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _selectedPrivacyLevel = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPrivacyLevelDescription(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Data Management
            _buildSectionHeader('Data Management', Icons.data_usage),
            
            _buildActionTile(
              icon: Icons.download,
              title: 'Download My Data',
              subtitle: 'Request a copy of all your data',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data download request submitted! Check your email.')),
                );
              },
            ),
            
            _buildActionTile(
              icon: Icons.cleaning_services,
              title: 'Clear Search History',
              subtitle: 'Remove all your search history',
              onTap: () => _showConfirmDialog('Clear Search History', 'Are you sure you want to clear all search history?'),
            ),
            
            _buildActionTile(
              icon: Icons.delete_sweep,
              title: 'Clear Cache',
              subtitle: 'Free up space by clearing cached data',
              onTap: () => _showConfirmDialog('Clear Cache', 'Clear all cached data? You will need to reload content.'),
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Account Actions
            _buildSectionHeader('Account Actions', Icons.account_circle),
            
            _buildActionTile(
              icon: Icons.history,
              title: 'Login History',
              subtitle: 'View your recent login activity',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Login history coming soon!')),
                );
              },
            ),
            
            _buildActionTile(
              icon: Icons.devices,
              title: 'Active Sessions',
              subtitle: 'Manage devices where you\'re logged in',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Active sessions coming soon!')),
                );
              },
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getPrivacyLevelDescription() {
    switch (_selectedPrivacyLevel) {
      case 'low':
        return 'Low: Your profile is public. Anyone can see your activity and saved recipes.';
      case 'medium':
        return 'Medium: Your profile is semi-private. Only logged-in users can see your activity.';
      case 'high':
        return 'High: Your profile is private. Only you can see your activity and saved recipes.';
      default:
        return '';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.orange),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.orange,
    );
  }

  Widget _buildActionTile({
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

  void _showConfirmDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title completed!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
