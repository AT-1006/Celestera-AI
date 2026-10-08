

// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nicknameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nicknameController.text = authProvider.nickname ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nickname cannot be empty')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.updateNickname(newNickname);

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nickname updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: authProvider.photoURL != null
                        ? CachedNetworkImageProvider(authProvider.photoURL!)
                        : null,
                    child: authProvider.photoURL == null
                        ? Text(
                            authProvider.nickname?.substring(0, 1).toUpperCase() ?? 'U',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Nickname Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nickname',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isEditing ? Icons.check : Icons.edit),
                          onPressed: () {
                            if (_isEditing) {
                              _saveNickname();
                            } else {
                              setState(() {
                                _isEditing = true;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextField(
                            controller: _nicknameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter your nickname',
                            ),
                            autofocus: true,
                          )
                        : Text(
                            authProvider.nickname ?? 'Not set',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Email Section
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(authProvider.email ?? 'Not available'),
              ),
            ),

            const SizedBox(height: 16),

            // Account Created Section
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Account Created'),
                subtitle: const Text('Not available'),
              ),
            ),

            const SizedBox(height: 32),

            // Delete Account Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDeleteAccount(context, authProvider),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _confirmDeleteAccount(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // TODO: Implement account deletion
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion - Coming Soon'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}