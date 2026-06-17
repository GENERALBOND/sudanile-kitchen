import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _recipeApprovalAlerts = true;
  bool _newRecipesAlerts = true;
  bool _communityUpdatesAlerts = true;
  bool _reviewRepliesAlerts = true;
  bool _weeklyDigest = false;
  bool _marketingEmails = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _recipeApprovalAlerts = prefs.getBool('recipe_approval_alerts') ?? true;
      _newRecipesAlerts = prefs.getBool('new_recipes_alerts') ?? true;
      _communityUpdatesAlerts = prefs.getBool('community_updates_alerts') ?? true;
      _reviewRepliesAlerts = prefs.getBool('review_replies_alerts') ?? true;
      _weeklyDigest = prefs.getBool('weekly_digest') ?? false;
      _marketingEmails = prefs.getBool('marketing_emails') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('email_notifications', _emailNotifications);
    await prefs.setBool('push_notifications', _pushNotifications);
    await prefs.setBool('recipe_approval_alerts', _recipeApprovalAlerts);
    await prefs.setBool('new_recipes_alerts', _newRecipesAlerts);
    await prefs.setBool('community_updates_alerts', _communityUpdatesAlerts);
    await prefs.setBool('review_replies_alerts', _reviewRepliesAlerts);
    await prefs.setBool('weekly_digest', _weeklyDigest);
    await prefs.setBool('marketing_emails', _marketingEmails);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification settings saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
            
            // Main Notification Toggles
            _buildSectionHeader('Notification Channels'),
            _buildSwitchTile(
              icon: Icons.email,
              title: 'Email Notifications',
              subtitle: 'Receive notifications via email',
              value: _emailNotifications,
              onChanged: (val) => setState(() => _emailNotifications = val),
            ),
            _buildSwitchTile(
              icon: Icons.notifications_active,
              title: 'Push Notifications',
              subtitle: 'Receive push notifications on your device',
              value: _pushNotifications,
              onChanged: (val) => setState(() => _pushNotifications = val),
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Recipe Related Alerts
            _buildSectionHeader('Recipe Alerts'),
            _buildSwitchTile(
              icon: Icons.check_circle,
              title: 'Recipe Approval',
              subtitle: 'Get notified when your submitted recipe is approved',
              value: _recipeApprovalAlerts,
              onChanged: (val) => setState(() => _recipeApprovalAlerts = val),
            ),
            _buildSwitchTile(
              icon: Icons.fiber_new,
              title: 'New Recipes',
              subtitle: 'Discover new recipes added to the collection',
              value: _newRecipesAlerts,
              onChanged: (val) => setState(() => _newRecipesAlerts = val),
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Community Updates
            _buildSectionHeader('Community Updates'),
            _buildSwitchTile(
              icon: Icons.people,
              title: 'Community Updates',
              subtitle: 'News and updates from the Sudanile Kitchen community',
              value: _communityUpdatesAlerts,
              onChanged: (val) => setState(() => _communityUpdatesAlerts = val),
            ),
            _buildSwitchTile(
              icon: Icons.comment,
              title: 'Review Replies',
              subtitle: 'Get notified when someone replies to your review',
              value: _reviewRepliesAlerts,
              onChanged: (val) => setState(() => _reviewRepliesAlerts = val),
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Digest & Marketing
            _buildSectionHeader('Digest & Marketing'),
            _buildSwitchTile(
              icon: Icons.calendar_today,
              title: 'Weekly Digest',
              subtitle: 'Weekly summary of popular recipes and community activity',
              value: _weeklyDigest,
              onChanged: (val) => setState(() => _weeklyDigest = val),
            ),
            _buildSwitchTile(
              icon: Icons.mark_email_read,
              title: 'Marketing Emails',
              subtitle: 'Special offers, events, and promotions',
              value: _marketingEmails,
              onChanged: (val) => setState(() => _marketingEmails = val),
            ),
            
            const SizedBox(height: 32),
            
            // Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can change these settings anytime. Push notifications require device permission.',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
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
}
