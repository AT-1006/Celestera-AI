import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/bot_config_service.dart';
import '../services/groq_service.dart';
import '../config/app_config.dart';

class BotSettingsScreen extends StatefulWidget {
  const BotSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BotSettingsScreen> createState() => _BotSettingsScreenState();
}

class _BotSettingsScreenState extends State<BotSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final BotConfigService _botConfigService = BotConfigService.instance;
  bool _isLoading = false;
  String _currentBotName = AppConfig.defaultBotName;

  @override
  void initState() {
    super.initState();
    _loadCurrentBotName();
  }

  Future<void> _loadCurrentBotName() async {
    try {
      await _botConfigService.loadBotConfig();
      setState(() {
        _currentBotName = _botConfigService.botName;
        _nameController.text = _currentBotName;
      });
    } catch (e) {
      debugPrint('Error loading bot name: $e');
      setState(() {
        _currentBotName = AppConfig.defaultBotName;
        _nameController.text = _currentBotName;
      });
    }
  }

  Future<void> _updateBotName() async {
    final newName = _nameController.text.trim();
    
    if (newName.isEmpty) {
      _showError('Bot name cannot be empty');
      return;
    }

    if (newName.length < 2 || newName.length > 20) {
      _showError('Bot name must be between 2 and 20 characters');
      return;
    }

    if (newName == _currentBotName) {
      _showError('Bot name is already set to "$newName"');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update Groq service if available
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.updateBotName(newName);
      
      setState(() {
        _currentBotName = newName;
        _isLoading = false;
      });

      _showSuccess('Bot name successfully changed to "$newName"');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to update bot name: $e');
    }
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Bot Name'),
          content: Text('Are you sure you want to reset the bot name to "${AppConfig.defaultBotName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                  await chatProvider.updateBotName(AppConfig.defaultBotName);
                  setState(() {
                    _currentBotName = AppConfig.defaultBotName;
                    _nameController.text = AppConfig.defaultBotName;
                    _isLoading = false;
                  });
                  _showSuccess('Bot name reset to "${AppConfig.defaultBotName}"');
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                  });
                  _showError('Failed to reset bot name: $e');
                }
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bot Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Bot Name Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Current Bot Name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _currentBotName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Change Bot Name Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Change Bot Name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'New Bot Name',
                        hintText: 'Enter a name for the bot',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        helperText: 'Name must be between 2 and 20 characters',
                      ),
                      maxLength: 20,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateBotName,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Update Name'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _isLoading ? null : _resetToDefault,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Reset'),
                      ),
                    ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Voice Command Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mic,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Voice Commands',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You can also change the bot name using voice commands:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildCommandExample('call you [new name]'),
                    _buildCommandExample('your name is [new name]'),
                    _buildCommandExample('change your name to [new name]'),
                    _buildCommandExample('rename yourself to [new name]'),
                    _buildCommandExample('from now on call you [new name]'),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The bot name change will be saved locally and will persist across app restarts.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandExample(String command) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              command,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
