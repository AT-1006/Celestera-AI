// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../services/chat_lock_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final chatLockService = chatProvider.chatLockService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme Color'),
            subtitle: Text(_getThemeLabel(themeProvider.selectedTheme)),
            trailing: DropdownButton<String>(
              value: themeProvider.selectedTheme,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'pink', child: Text('Pink')),
                DropdownMenuItem(value: 'green', child: Text('Green')),
                DropdownMenuItem(value: 'blue', child: Text('Blue')),
                DropdownMenuItem(value: 'yellow', child: Text('Yellow')),
                DropdownMenuItem(value: 'white', child: Text('White')),
              ],
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeColor(value);
                }
              },
            ),
          ),

          ListTile(
            leading: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : themeProvider.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_auto,
            ),
            title: const Text('Theme Mode'),
            subtitle: Text(_getModeLabel(themeProvider.themeMode)),
            trailing: DropdownButton<ThemeMode>(
              value: themeProvider.themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                }
              },
            ),
          ),

          const Divider(),

          // Chat Lock Section
          _buildSectionHeader('Chat Lock Security'),

          FutureBuilder<bool>(
            future: chatLockService.isGlobalPinSet(),
            builder: (context, snapshot) {
              final isPinSet = snapshot.data ?? false;
              
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: Text(isPinSet ? 'Change PIN' : 'Set PIN'),
                    subtitle: Text(isPinSet 
                        ? 'Change your chat lock PIN' 
                        : 'Set a PIN to lock your chats'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showPinManagementDialog(context, chatLockService, isPinSet),
                  ),
                  
                  if (isPinSet)
                    ListTile(
                      leading: const Icon(Icons.lock_open, color: Colors.red),
                      title: const Text('Remove PIN'),
                      subtitle: const Text('Remove chat lock PIN (requires current PIN)'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showRemovePinDialog(context, chatLockService),
                    ),
                ],
              );
            },
          ),

          const Divider(),

          // Chat Settings Section
          _buildSectionHeader('Chat Settings'),

          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Clear All Chats'),
            subtitle: const Text('Delete all chat history'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _confirmClearAllChats(context, chatProvider),
          ),

          const Divider(),

          // About Section
          _buildSectionHeader('About'),

          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),

          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open privacy policy
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy Policy - Coming Soon')),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open terms of service
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of Service - Coming Soon')),
              );
            },
          ),
        ],
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

  String _getThemeLabel(String theme) {
    return theme[0].toUpperCase() + theme.substring(1);
  }

  String _getModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _confirmClearAllChats(BuildContext context, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Chats'),
        content: const Text(
          'Are you sure you want to delete all chats? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Delete all chats
              for (var chat in chatProvider.chats) {
                await chatProvider.deleteChat(chat.id);
              }
              chatProvider.clearMessages();
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All chats cleared')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showPinManagementDialog(BuildContext context, ChatLockService chatLockService, bool isPinSet) {
    if (isPinSet) {
      _showChangePinDialog(context, chatLockService);
    } else {
      _showSetPinDialog(context, chatLockService);
    }
  }

  void _showSetPinDialog(BuildContext context, ChatLockService chatLockService) {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isPinVisible = false;
    bool isConfirmPinVisible = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set Chat Lock PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set a PIN to lock your chats. This PIN will be used for all chat locks.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: !isPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Enter PIN (4-6 digits)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(isPinVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => isPinVisible = !isPinVisible);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPinController,
                obscureText: !isConfirmPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(isConfirmPinVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => isConfirmPinVisible = !isConfirmPinVisible);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinController.text;
                final confirmPin = confirmPinController.text;
                
                if (pin.length < 4 || pin.length > 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN must be 4-6 digits')),
                  );
                  return;
                }
                
                if (pin != confirmPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PINs do not match')),
                  );
                  return;
                }
                
                await chatLockService.storeGlobalPin(pin);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN set successfully')),
                );
              },
              child: const Text('Set PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, ChatLockService chatLockService) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isCurrentPinVisible = false;
    bool isNewPinVisible = false;
    bool isConfirmPinVisible = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Chat Lock PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPinController,
                obscureText: !isCurrentPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(isCurrentPinVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => isCurrentPinVisible = !isCurrentPinVisible);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPinController,
                obscureText: !isNewPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'New PIN (4-6 digits)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(isNewPinVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => isNewPinVisible = !isNewPinVisible);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPinController,
                obscureText: !isConfirmPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Confirm New PIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(isConfirmPinVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => isConfirmPinVisible = !isConfirmPinVisible);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPin = currentPinController.text;
                final newPin = newPinController.text;
                final confirmPin = confirmPinController.text;
                
                // Verify current PIN
                final storedPin = await chatLockService.getGlobalPin();
                if (storedPin != currentPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Current PIN is incorrect')),
                  );
                  return;
                }
                
                if (newPin.length < 4 || newPin.length > 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN must be 4-6 digits')),
                  );
                  return;
                }
                
                if (newPin != confirmPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New PINs do not match')),
                  );
                  return;
                }
                
                await chatLockService.storeGlobalPin(newPin);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN changed successfully')),
                );
              },
              child: const Text('Change PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemovePinDialog(BuildContext context, ChatLockService chatLockService) {
    final pinController = TextEditingController();
    bool isPinVisible = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Remove Chat Lock PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Removing the PIN will disable chat lock functionality. All locked chats will be unlocked.',
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: !isPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Enter Current PIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(isPinVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => isPinVisible = !isPinVisible);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinController.text;
                
                // Verify current PIN
                final storedPin = await chatLockService.getGlobalPin();
                if (storedPin != pin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                  return;
                }
                
                await chatLockService.clearGlobalPin();
                await chatLockService.removeChatLock();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN removed successfully')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove PIN'),
            ),
          ],
        ),
      ),
    );
  }
}