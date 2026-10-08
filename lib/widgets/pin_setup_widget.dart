import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/chat_lock_service.dart';

class PinSetupWidget extends StatefulWidget {
  final VoidCallback onPinSet;
  final VoidCallback onCancelled;

  const PinSetupWidget({
    super.key,
    required this.onPinSet,
    required this.onCancelled,
  });

  @override
  State<PinSetupWidget> createState() => _PinSetupWidgetState();
}

class _PinSetupWidgetState extends State<PinSetupWidget> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final ChatLockService _lockService = ChatLockService();
  bool _showConfirm = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock Icon
            Icon(
              Icons.lock,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              _showConfirm ? 'Confirm PIN' : 'Set Chat Lock PIN',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              _showConfirm 
                  ? 'Re-enter your PIN to confirm'
                  : 'Create a 4-6 digit PIN to lock your chats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            
            // PIN Input
            TextField(
              controller: _showConfirm ? _confirmPinController : _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                hintText: '••••',
                hintStyle: TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                ),
              ),
              onSubmitted: (_) => _handleNext(),
            ),
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : widget.onCancelled,
                    child: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleNext,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_showConfirm ? 'Confirm' : 'Next'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleNext() {
    final pin = _showConfirm ? _confirmPinController.text.trim() : _pinController.text.trim();
    
    if (!_lockService.validatePin(pin)) {
      _showError('PIN must be 4-6 digits');
      return;
    }

    if (!_showConfirm) {
      setState(() {
        _showConfirm = true;
      });
      return;
    }

    if (_pinController.text.trim() != _confirmPinController.text.trim()) {
      _showError('PINs do not match');
      return;
    }

    _savePin();
  }

  Future<void> _savePin() async {
    setState(() => _isLoading = true);

    try {
      await _lockService.storeGlobalPin(_pinController.text.trim());
      widget.onPinSet();
    } catch (e) {
      _showError('Failed to save PIN');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
