import 'package:flutter/material.dart';
import '../services/persona_service.dart';

class BotSelectionModal extends StatelessWidget {
  final BotPersona currentPersona;
  final Function(BotPersona) onPersonaSelected;

  const BotSelectionModal({
    super.key,
    required this.currentPersona,
    required this.onPersonaSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose AI Assistant',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Select the specialized AI that best fits your needs',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Bot Options
            ...BotPersona.values.map((persona) => _buildBotOption(
              context,
              persona,
              persona == currentPersona,
            )),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBotOption(BuildContext context, BotPersona persona, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onPersonaSelected(persona);
            Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                // Bot Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 24,
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Bot Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            persona.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        persona.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection Indicator
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Ear Mic Button Widget
class EarMicButton extends StatelessWidget {
  final BotPersona currentPersona;
  final VoidCallback onPressed;

  const EarMicButton({
    super.key,
    required this.currentPersona,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Tooltip(
        message: 'Current AI: ${currentPersona.name}\nTap to change AI assistant',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ear/Mic Icon
                  Icon(
                    Icons.hearing_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Bot Icon
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Bot Name
                  Text(
                    currentPersona.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
