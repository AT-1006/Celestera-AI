import 'dart:io';
import 'dart:convert';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

class DocumentService {
  static Future<String?> readDocument(File file) async {
    try {
      final extension = file.path.toLowerCase().split('.').last;
      
      switch (extension) {
        case 'txt':
          return await _readTextFile(file);
        case 'pdf':
          return 'PDF document detected. PDF processing requires additional libraries. The file has been uploaded and can be processed by the AI model.';
        case 'doc':
        case 'docx':
          return 'Word document detected. Document processing requires additional libraries. The file has been uploaded and can be processed by the AI model.';
        default:
          throw UnsupportedError('Unsupported file format: $extension');
      }
    } catch (e) {
      print('Error reading document: $e');
      return null;
    }
  }
  
  static Future<String> _readTextFile(File file) async {
    try {
      return await file.readAsString(encoding: utf8);
    } catch (e) {
      // Try different encodings if UTF-8 fails
      try {
        return await file.readAsString(encoding: latin1);
      } catch (e2) {
        throw Exception('Failed to read text file with multiple encodings');
      }
    }
  }
  
  static String getFileExtension(File file) {
    return file.path.toLowerCase().split('.').last;
  }
  
  static bool isSupportedDocument(String extension) {
    return ['txt', 'pdf', 'doc', 'docx'].contains(extension.toLowerCase());
  }
  
  static String getDocumentIcon(String extension) {
    switch (extension.toLowerCase()) {
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
  
  static String getDocumentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'txt':
        return 'Text File';
      default:
        return 'Document';
    }
  }
  
  static Future<String> summarizeDocumentContent(String content, {int maxLength = 1000}) async {
    if (content.length <= maxLength) {
      return content;
    }
    
    // Simple truncation for now
    // In a real implementation, you might want to use AI to summarize
    return '${content.substring(0, maxLength)}...\n\n[Document truncated - full content available for analysis]';
  }
}
