import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../providers/favorites_provider.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _isDeletingAccount = false;
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscureDelete = true;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user != null) {
      _usernameController.text = authService.user!.username;
      _bioController.text = authService.user!.bio ?? '';
    }
  }

  Future<void> _updateProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      await apiService.put('/users/profile/', {
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.refreshUser();
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _editProfilePhoto() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final hasPhoto = (authService.user?.profilePicture ?? '').isNotEmpty;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || choice == 'cancel' || !mounted) return;

    if (choice == 'remove') {
      await _removeProfilePhoto();
      return;
    }

    final XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open the camera on this device.')),
      );
      return;
    }
    if (image == null || !mounted) return;

    await _uploadProfilePhoto(image);
  }

  Future<void> _uploadProfilePhoto(XFile image) async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      final bytes = await image.readAsBytes();
      await apiService.postMultipart(
        '/users/upload-profile-picture/',
        const {},
        fileField: 'image',
        fileBytes: bytes,
        filename: image.name,
        fileContentType: _mediaTypeFor(image),
      );

      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: ${e.toString()}')),
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _removeProfilePhoto() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      await apiService.delete('/users/upload-profile-picture/');

      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove photo: ${e.toString()}')),
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  MediaType _mediaTypeFor(XFile image) {
    final mime = image.mimeType;
    if (mime != null) {
      final parts = mime.split('/');
      if (parts.length == 2) return MediaType(parts[0], parts[1]);
    }
    final name = image.name.toLowerCase();
    if (name.endsWith('.gif')) return MediaType('image', 'gif');
    if (name.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your current password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content:
                Text('Password changed successfully! Please login again.')),
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isChangingPassword = false);

      final favProvider =
          Provider.of<FavoritesProvider>(context, listen: false);
      await authService.logout();
      favProvider.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed to change password.')),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _deleteAccount() async {
    if (_deletePasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please enter your password to confirm account deletion')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.deleteAccount(_deletePasswordController.text);

    if (!mounted) return;

    if (result['success'] == true) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      Provider.of<FavoritesProvider>(context, listen: false).clear();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text(
                'Account deleted successfully. We\'re sad to see you go!')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed to delete account.')),
      );
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isDeletingAccount = false;
      _deletePasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Section
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: user.profilePicture != null
                            ? NetworkImage(user.profilePicture!)
                            : null,
                        child: user.profilePicture == null
                            ? Text(
                                user.username[0].toUpperCase(),
                                style: const TextStyle(fontSize: 40),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt,
                                size: 20, color: Colors.white),
                            onPressed: _editProfilePhoto,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Edit Profile Section
            if (!_isEditing) ...[
              _buildInfoTile(context, 'Username', user.username),
              _buildInfoTile(context, 'Bio',
                  user.bio?.isNotEmpty == true ? user.bio! : 'No bio yet'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ] else ...[
              const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell us about yourself...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isEditing = false);
                        _usernameController.text = user.username;
                        _bioController.text = user.bio ?? '';
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Change Password Section
            if (!_isChangingPassword) ...[
              const Divider(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _isChangingPassword = true),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Change Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ] else ...[
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isChangingPassword = false);
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Appearance - Dark / Light mode
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how the app looks. System follows your device setting.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return SegmentedButton<AppThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: AppThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {themeProvider.mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    themeProvider.setMode(selection.first);
                  },
                );
              },
            ),

            const SizedBox(height: 32),

            // Danger Zone - Delete Account
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(12),
                color: Colors.red.shade50,
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Danger Zone',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.red, height: 1),
                  if (!_isDeletingAccount) ...[
                    ListTile(
                      leading:
                          const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text('Delete Account',
                          style: TextStyle(color: Colors.red)),
                      subtitle: const Text(
                          'Permanently delete your account and all data'),
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.red),
                      onTap: () => setState(() => _isDeletingAccount = true),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This action is permanent and cannot be undone. '
                            'All your recipes, favorites, reviews, and personal data will be deleted.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _deletePasswordController,
                            obscureText: _obscureDelete,
                            decoration: InputDecoration(
                              labelText: 'Enter your password to confirm',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureDelete
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscureDelete = !_obscureDelete),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isDeletingAccount = false;
                                      _deletePasswordController.clear();
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _deleteAccount,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Permanently Delete'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
