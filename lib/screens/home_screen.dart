import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/bot_selection_modal.dart';
import '../services/persona_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedImage;
  File? _selectedDocument;
  bool _isChatLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Set the user ID in ChatProvider
      if (authProvider.userId != null) {
        chatProvider.setUserId(authProvider.userId!);
      }
      
      // Initialize voice and update lock status
      _initializeVoice();
      _updateLockStatus();
      
      // Listen for chat changes
      chatProvider.addListener(_updateLockStatus);
    });
  }

  @override
  void dispose() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.removeListener(_updateLockStatus);
    super.dispose();
  }

  Future<void> _initializeVoice() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.initializeSpeech();
  }

  Future<void> _updateLockStatus() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.currentChat != null) {
      final isLocked = await chatProvider.isChatLocked(chatProvider.currentChat!.id);
      if (mounted) {
        setState(() {
          _isChatLocked = isLocked;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDocument() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? document = await picker.pickMedia();
      
      if (document != null) {
        setState(() {
          _selectedDocument = File(document.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document selected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _clearDocument() {
    setState(() {
      _selectedDocument = null;
    });
  }

  void _showBotSelectionModal() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => BotSelectionModal(
        currentPersona: chatProvider.currentPersona,
        onPersonaSelected: (persona) async {
          await chatProvider.setPersona(persona);
        },
      ),
    );
  }

  Future<void> _selectChat(String chatId) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Select chat directly (lock functionality not implemented)
    chatProvider.selectChat(chatId);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImage == null && _selectedDocument == null) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Determine the message text based on attachments
    String messageText = message;
    if (message.isEmpty) {
      if (_selectedImage != null && _selectedDocument != null) {
        messageText = '[Image and Document]';
      } else if (_selectedImage != null) {
        messageText = '[Image]';
      } else if (_selectedDocument != null) {
        messageText = '[Document]';
      }
    }
    
    await chatProvider.sendMessage(
      messageText,
      image: _selectedImage,
      document: _selectedDocument,
    );

    _messageController.clear();
    setState(() {
      _selectedImage = null;
      _selectedDocument = null;
    });
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<ChatProvider>(
          builder: (context, chatProvider, _) {
            return Text(
              chatProvider.currentChat?.title ?? 'AI Chatbot',
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        actions: [
          // Bot Selection Button
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              return EarMicButton(
                currentPersona: chatProvider.currentPersona,
                onPressed: _showBotSelectionModal,
              );
            },
          ),
          const SizedBox(width: 8),
          // Lock/Unlock Menu
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'lock') {
                    await _handleLockChat(chatProvider);
                  } else if (value == 'unlock') {
                    await _handleUnlockChat(chatProvider);
                  }
                },
                itemBuilder: (context) {
                  return [
                    if (!_isChatLocked)
                      const PopupMenuItem(
                        value: 'lock',
                        child: Row(
                          children: [
                            Icon(Icons.lock),
                            SizedBox(width: 8),
                            Text('Lock Chat'),
                          ],
                        ),
                      ),
                    if (_isChatLocked)
                      const PopupMenuItem(
                        value: 'unlock',
                        child: Row(
                          children: [
                            Icon(Icons.lock_open),
                            SizedBox(width: 8),
                            Text('Unlock Chat'),
                          ],
                        ),
                      ),
                  ];
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Provider.of<ChatProvider>(context, listen: false).createNewChat();
            },
            tooltip: 'New Chat',
          ),
        ],
      ),
      drawer: const SidebarDrawer(),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatProvider.messages.length + (chatProvider.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chatProvider.messages.length) {
                      return const TypingIndicator();
                    }
                    
                    final message = chatProvider.messages[index];
                    return MessageBubble(message: message);
                  },
                );
              },
            ),
          ),

          // Image preview
          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Image selected'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Document preview
          if (_selectedDocument != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _getDocumentIcon(_selectedDocument!.path),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document attached',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _selectedDocument!.path.split('/').last,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedDocument = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Attachment preview
                if (_selectedImage != null || _selectedDocument != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image preview
                        if (_selectedImage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Image',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      Text(
                                        'Tap to remove',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodySmall?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _clearImage,
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Remove image',
                                ),
                              ],
                            ),
                          ),
                        
                        // Document preview
                        if (_selectedDocument != null)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Document',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    Text(
                                      'Tap to remove',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _clearDocument,
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove document',
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                
                // Input row
                Row(
                  children: [
                // Image picker button
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickImage,
                  tooltip: 'Add Image',
                ),
                
                // Document picker button
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickDocument,
                  tooltip: 'Attach Document',
                ),
                
                // Text input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Voice button
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, _) {
                    return GestureDetector(
                      onTap: () async {
                        if (chatProvider.isVoiceChatMode) {
                          // If in voice chat mode, exit it
                          await chatProvider.toggleVoiceChatMode();
                        } else if (chatProvider.isVoiceListening) {
                          // If currently listening normally, stop it
                          await chatProvider.stopVoiceListening();
                        } else {
                          // Start continuous voice chat mode
                          await chatProvider.toggleVoiceChatMode();
                        }
                      },
                      onLongPress: () async {
                        // Long press now just does single voice command
                        if (!chatProvider.isVoiceChatMode) {
                          await chatProvider.startVoiceListening();
                        }
                      },
                      child: Tooltip(
                        message: chatProvider.isVoiceChatMode 
                            ? 'Tap to exit voice chat mode\nTap while listening to stop early (10-sec limit)\nLong press for single command'
                            : 'Tap to start voice chat mode (10-sec cycles)\nLong press for single command',
                        child: Container(
                          decoration: BoxDecoration(
                            color: chatProvider.isVoiceChatMode
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                : chatProvider.isVoiceListening
                                    ? Colors.red.withOpacity(0.1)
                                    : chatProvider.isVoiceSpeaking
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                        : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: chatProvider.isVoiceChatMode
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  chatProvider.isVoiceChatMode
                                      ? Icons.mic
                                      : chatProvider.isVoiceListening
                                          ? Icons.stop_circle_rounded
                                          : Icons.mic_rounded,
                                  color: chatProvider.isVoiceChatMode
                                      ? Theme.of(context).colorScheme.primary
                                      : chatProvider.isVoiceListening
                                          ? Colors.red
                                          : chatProvider.isVoiceSpeaking
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  size: 24,
                                ),
                                if (chatProvider.isVoiceChatMode)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (chatProvider.isVoiceListening)
                                        Text(
                                          '10s',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      Text(
                                        'Live',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(width: 8),
                
                // Send button or Stop button
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, _) {
                    return IconButton(
                      icon: chatProvider.isLoading
                          ? const Icon(Icons.stop_rounded)
                          : const Icon(Icons.send_rounded),
                      onPressed: chatProvider.isLoading
                          ? () {
                              debugPrint('🛑 User pressed stop button');
                              chatProvider.stopLoading();
                            }
                          : _sendMessage,
                      style: IconButton.styleFrom(
                        backgroundColor: chatProvider.isLoading
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: chatProvider.isLoading
                            ? Colors.white
                            : Theme.of(context).colorScheme.onPrimary,
                      ),
                      tooltip: chatProvider.isLoading ? 'Stop Loading' : 'Send Message',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      ],
      ),
    );
  }

  String _getDocumentIcon(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'txt':
        return '📃';
      default:
        return '📄';
    }
  }

  Future<void> _handleLockChat(ChatProvider chatProvider) async {
    if (chatProvider.currentChat == null) return;
    
    // Check if PIN is already set
    final chatLockService = chatProvider.chatLockService;
    final isPinSet = await chatLockService.isGlobalPinSet();
    
    debugPrint(' Lock Chat - PIN already set: $isPinSet');
    debugPrint(' Lock Chat - User ID: ${chatProvider.currentUserId}');
    
    if (!isPinSet) {
      debugPrint(' PIN not set, showing set PIN dialog');
      // Show dialog to set PIN first
      _showSetPinDialog(chatProvider, chatProvider.currentChat!.id);
    } else {
      debugPrint(' PIN already set, locking chat directly');
      // Lock the chat directly without asking for PIN
      await chatProvider.lockChat(chatProvider.currentChat!.id);
      setState(() {
        _isChatLocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat locked successfully')),
      );
    }
  }

  Future<void> _handleUnlockChat(ChatProvider chatProvider) async {
    _showUnlockDialog(chatProvider);
  }

  void _showSetPinDialog(ChatProvider chatProvider, String chatId) {
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
                
                // Store the PIN and lock the chat
                await chatProvider.chatLockService.storeGlobalPin(pin);
                await chatProvider.lockChat(chatId);
                
                Navigator.pop(context);
                setState(() {
                  _isChatLocked = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN set and chat locked successfully')),
                );
              },
              child: const Text('Set PIN & Lock'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnlockDialog(ChatProvider chatProvider) {
    final pinController = TextEditingController();
    bool isPinVisible = false;
    bool isBiometricAvailable = false;
    String biometricLabel = 'Biometric';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Unlock Chat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose how to unlock this chat'),
              const SizedBox(height: 16),
              
              // Biometric option
              FutureBuilder<bool>(
                future: chatProvider.chatLockService.isBiometricAvailable(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == true) {
                    return FutureBuilder<String>(
                      future: chatProvider.chatLockService.getBiometricLabel(),
                      builder: (context, labelSnapshot) {
                        final label = labelSnapshot.data ?? 'Biometric';
                        return Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final success = await chatProvider.unlockChatWithBiometrics();
                              if (success) {
                                setState(() {
                                  _isChatLocked = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Chat unlocked with $label')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Biometric authentication failed')),
                                );
                              }
                            },
                            icon: const Icon(Icons.fingerprint),
                            label: Text('Use $label'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              const SizedBox(height: 12),
              
              // PIN option
              const Text('Or enter your PIN'),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                obscureText: !isPinVisible,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Enter PIN',
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
                
                if (await chatProvider.unlockChatWithPin(pin)) {
                  Navigator.pop(context);
                  setState(() {
                    _isChatLocked = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat unlocked successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                }
              },
              child: const Text('Unlock with PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
