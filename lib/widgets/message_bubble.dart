// lib/widgets/message_bubble.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/message_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;

  const MessageBubble({super.key, required this.message});

  // Copy text to clipboard
  void _copyText(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Download image to local device
  Future<void> _downloadImage(BuildContext context) async {
    try {
      if (message.imagePath == null) return;

      String sourcePath;
      String fileName;

      if (message.imagePath!.startsWith('http://') || message.imagePath!.startsWith('https://')) {
        // For network images, we'd need to download first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network image download not yet supported')),
        );
        return;
      } else {
        // Local file
        sourcePath = message.imagePath!;
        fileName = path.basename(sourcePath);
      }

      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source file not found')),
        );
        return;
      }

      // Get downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access downloads directory')),
        );
        return;
      }

      // Create downloads directory if it doesn't exist
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Copy file to downloads
      final destinationPath = path.join(downloadsDir.path, fileName);
      await sourceFile.copy(destinationPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image saved to Downloads: $fileName'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error downloading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeFormat = DateFormat('HH:mm');

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image if present
                  if (message.imagePath != null) ...[
                    GestureDetector(
                      onTap: () => _downloadImage(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImage(message.imagePath!),
                      ),
                    ),
                    if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ],
                  
                  // Document if present
                  if (message.documentPath != null) ...[
                    GestureDetector(
                      onTap: () async {
                        final Uri uri = Uri.parse(message.documentPath!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open document')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
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
                                      color: isUser
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to view',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isUser
                                          ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)
                                          : Theme.of(context).textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              color: isUser
                                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)
                                  : Theme.of(context).textTheme.bodySmall?.color,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ],
                  
                  // Message text
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),
            
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeFormat.format(message.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                  // Add action buttons for bot messages
                  if (!isUser) ...[
                    const SizedBox(width: 8),
                    // Copy text button
                    if (message.content.isNotEmpty)
                      GestureDetector(
                        onTap: () => _copyText(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                      ),
                    // Download image button
                    if (message.imagePath != null)
                      GestureDetector(
                        onTap: () => _downloadImage(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.download,
                            size: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    // Check if it's a network URL or local file path
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // Network image
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Network image error: $error');
          return Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 40),
                SizedBox(height: 8),
                Text('Failed to load', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    } else {
      // Local file
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Local image error: $error');
            return Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 40),
                  SizedBox(height: 8),
                  Text('Failed to load', style: TextStyle(fontSize: 12)),
                ],
              ),
            );
          },
        );
      } else {
        debugPrint('❌ Local file not found: $imagePath');
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 40),
              SizedBox(height: 8),
              Text('File not found', style: TextStyle(fontSize: 12)),
            ],
          ),
        );
      }
    }
  }
}

