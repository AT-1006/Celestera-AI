import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/settings_screen.dart';
import '../screens/account_screen.dart';
import '../widgets/pin_setup_widget.dart';
import '../widgets/chat_lock_widget.dart';
import '../services/chat_lock_service.dart';

class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({super.key});

  Future<void> _checkAndSelectChat(String chatId, BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Check if chat is locked
    final isLocked = await chatProvider.isChatLocked(chatId);
    
    if (isLocked) {
      // Show lock dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ChatLockWidget(
          chatId: chatId,
          onUnlocked: () {
            Navigator.pop(context); // Close lock dialog
            chatProvider.selectChat(chatId); // Select chat after unlock
          },
          onCancelled: () {
            Navigator.pop(context); // Close lock dialog
          },
        ),
      );
    } else {
      // Chat is not locked, select it directly
      chatProvider.selectChat(chatId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Pinned user header ───────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundImage: authProvider.photoURL != null
                        ? CachedNetworkImageProvider(authProvider.photoURL!)
                        : null,
                    child: authProvider.photoURL == null
                        ? Text(
                            authProvider.nickname?.substring(0, 1).toUpperCase() ?? 'U',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    authProvider.nickname ?? 'User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  Text(
                    authProvider.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Chat History header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chat History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            chatProvider.createNewChat();
                            Navigator.pop(context);
                          },
                          tooltip: 'New Chat',
                        ),
                      ],
                    ),
                  ),

                  // Chat list items
                  if (chatProvider.chats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No chats yet',
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                      ),
                    )
                  else
                    ...chatProvider.chats.map((chat) {
                      final isSelected = chatProvider.currentChat?.id == chat.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                              : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.chat_bubble_outline,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              _formatDate(chat.updatedAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: PopupMenuButton(
                              icon: const Icon(Icons.more_vert),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Rename'),
                                    ],
                                  ),
                                  onTap: () => _showRenameDialog(context, chat.id, chat.title),
                                ),
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.lock, size: 20, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Lock Chat'),
                                    ],
                                  ),
                                  onTap: () async {
                                    await _showLockDialog(context, chat.id);
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                  onTap: () => _confirmDelete(context, chat.id),
                                ),
                              ],
                            ),
                            onTap: () {
                              _checkAndSelectChat(chat.id, context);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    }),

                  const Divider(height: 24),

                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Account'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountScreen()),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),

                  ExpansionTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Theme'),
                    children: [
                      _buildThemeOption(context, 'Pink', 'pink'),
                      _buildThemeOption(context, 'Green', 'green'),
                      _buildThemeOption(context, 'Blue', 'blue'),
                      _buildThemeOption(context, 'Yellow', 'yellow'),
                      _buildThemeOption(context, 'White', 'white'),
                    ],
                  ),

                  // ── Mode selector ────────────────────────────
                  // Button sits BELOW the label row so it always
                  // has the full drawer width — no overflow possible.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? Icons.dark_mode
                                  : themeProvider.themeMode == ThemeMode.light
                                      ? Icons.light_mode
                                      : Icons.brightness_auto,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            const Text('Mode', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ThemeMode>(
                          expandedInsets: EdgeInsets.zero,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode, size: 16),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto, size: 16),
                              label: Text('Auto'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode, size: 16),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {themeProvider.themeMode},
                          onSelectionChanged: (Set<ThemeMode> selection) {
                            themeProvider.setThemeMode(selection.first);
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 24),

                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () => _confirmLogout(context),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, String themeKey) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSelected = themeProvider.selectedTheme == themeKey;

    return RadioListTile<String>(
      title: Text(label),
      value: themeKey,
      groupValue: themeProvider.selectedTheme,
      selected: isSelected,
      onChanged: (value) {
        if (value != null) {
          themeProvider.setThemeColor(value);
        }
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showRenameDialog(BuildContext context, String chatId, String currentTitle) {
    Future.delayed(Duration.zero, () {
      final controller = TextEditingController(text: currentTitle);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename Chat'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'New name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  Provider.of<ChatProvider>(context, listen: false)
                      .renameChat(chatId, newTitle);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    });
  }

  void _confirmDelete(BuildContext context, String chatId) {
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
              'Are you sure you want to delete this chat? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<ChatProvider>(context, listen: false).deleteChat(chatId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _showLockDialog(BuildContext context, String chatId) async {
    final chatLockService = ChatLockService();
    final isPinSet = await chatLockService.isGlobalPinSet();
    
    if (!isPinSet) {
      // First time setup PIN
      showDialog(
        context: context,
        builder: (context) => PinSetupWidget(
          onPinSet: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN set successfully! You can now lock chats.'),
                backgroundColor: Colors.green,
              ),
            );
          },
          onCancelled: () => Navigator.pop(context),
        ),
      );
    } else {
      // Show PIN input dialog to lock chat
      final pinController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lock Chat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your PIN to lock this chat:'),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '••••',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
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
                final pin = pinController.text.trim();
                if (chatLockService.validatePin(pin)) {
                  await chatLockService.lockChat(chatId);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat locked successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN must be 4-6 digits'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Lock'),
            ),
          ],
        ),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}