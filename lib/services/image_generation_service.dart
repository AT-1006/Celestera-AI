import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ImageGenerationService {
  static final ImageGenerationService _instance = ImageGenerationService._internal();
  factory ImageGenerationService() => _instance;
  
  final Dio _dio = Dio();
  
  ImageGenerationService._internal() {
    // Configure Dio with timeout
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60); // Image generation can take time
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }
  
  // Your Cloudflare Worker API details
  static const String _apiUrl = 'https://image-api.atharvgawand2.workers.dev';
  static const String _apiKey = '1234567890';

  /// Generate image from text prompt
  Future<File?> generateImage(String prompt) async {
    try {
      debugPrint('🎨 Generating image for prompt: $prompt');
      debugPrint('🌐 API URL: $_apiUrl');
      
      final response = await _dio.post(
        _apiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          followRedirects: true,
          maxRedirects: 5,
          receiveTimeout: const Duration(seconds: 90), // Longer timeout for image generation
        ),
        data: jsonEncode({'prompt': prompt}),
      );

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📊 Response headers: ${response.headers}');
      debugPrint('📊 Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        debugPrint('✅ Image generated successfully');
        
        // Handle different response data types
        List<int> bytes;
        if (response.data is List<int>) {
          bytes = response.data as List<int>;
        } else if (response.data is String) {
          // If it's a base64 string, decode it
          String base64String = response.data as String;
          
          debugPrint('🔍 Analyzing string response...');
          debugPrint('🔍 String length: ${base64String.length}');
          debugPrint('🔍 First 50 chars: ${base64String.substring(0, 50)}');
          
          // Check if it looks like it has binary data mixed with base64
          // Look for the PNG signature and remove everything before actual base64
          if (base64String.contains('PNG')) {
            debugPrint('🗂️ Found PNG marker in string');
            
            // Find the actual base64 data - look for patterns that indicate start of base64
            final pngIndex = base64String.indexOf('PNG');
            if (pngIndex != -1) {
              // Try to find where readable text starts after PNG header
              var afterPng = base64String.substring(pngIndex + 3);
              
              // Remove any non-base64 characters from the beginning
              afterPng = afterPng.replaceAll(RegExp(r'[^\w+/=]'), '');
              
              if (afterPng.isNotEmpty) {
                base64String = afterPng;
                debugPrint('🗂️ Cleaned base64 string, length: ${base64String.length}');
              }
            }
          }
          
          try {
            // Add proper padding to base64 string
            String paddedBase64 = base64String;
            
            // Calculate required padding
            final paddingLength = (4 - (base64String.length % 4)) % 4;
            if (paddingLength > 0) {
              paddedBase64 = base64String + '=' * paddingLength;
              debugPrint('🔧 Added $paddingLength characters of padding to base64 string');
            }
            
            bytes = base64.decode(paddedBase64);
            debugPrint('✅ Successfully decoded base64 to ${bytes.length} bytes');
          } catch (e) {
            debugPrint('❌ Failed to decode base64 string: $e');
            debugPrint('❌ Base64 string length: ${base64String.length}');
            debugPrint('❌ Base64 string preview: ${base64String.substring(0, 100)}');
            return null;
          }
        } else if (response.data is Uint8List) {
          bytes = (response.data as Uint8List).toList();
        } else {
          debugPrint('❌ Unexpected response data type: ${response.data.runtimeType}');
          debugPrint('❌ Response data: ${response.data}');
          return null;
        }
        
        debugPrint('📊 Image size: ${bytes.length} bytes');
        
        if (bytes.isEmpty) {
          debugPrint('❌ Empty image data received');
          return null;
        }
        
        final tempDir = Directory.systemTemp;
        final fileName = 'generated_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageFile = File('${tempDir.path}/$fileName');
        
        await imageFile.writeAsBytes(bytes);
        debugPrint('📁 Image saved to: ${imageFile.path}');
        
        return imageFile;
      } else {
        debugPrint('❌ Image generation failed: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      debugPrint('🔥 Dio error generating image: ${e.type}');
      debugPrint('🔥 Error message: ${e.message}');
      debugPrint('🔥 Response: ${e.response}');
      debugPrint('🔥 Response status: ${e.response?.statusCode}');
      return null;
    } catch (e) {
      debugPrint('🔥 Error generating image: $e');
      debugPrint('🔥 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Generate image and return as bytes (for direct display)
  Future<List<int>?> generateImageBytes(String prompt) async {
    try {
      debugPrint('🎨 Generating image for prompt: $prompt');
      
      final response = await _dio.post(
        _apiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60), // Increased timeout
          sendTimeout: const Duration(seconds: 30),
        ),
        data: jsonEncode({'prompt': prompt}),
      );

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📊 Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        debugPrint('✅ Image generated successfully');
        
        // Handle different response formats
        List<int> bytes;
        if (response.data is List<int>) {
          bytes = response.data as List<int>;
        } else if (response.data is Uint8List) {
          bytes = (response.data as Uint8List).toList();
        } else {
          debugPrint('❌ Unexpected response data type: ${response.data.runtimeType}');
          return null;
        }
        
        debugPrint('📊 Image size: ${bytes.length} bytes');
        
        if (bytes.isEmpty) {
          debugPrint('❌ Empty image data received');
          return null;
        }
        
        return bytes;
      } else {
        debugPrint('❌ Image generation failed: ${response.statusCode}');
        debugPrint('❌ Response data: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      debugPrint('🔥 Dio error generating image: ${e.type}');
      debugPrint('🔥 Error message: ${e.message}');
      debugPrint('🔥 Response status: ${e.response?.statusCode}');
      debugPrint('🔥 Response data: ${e.response?.data}');
      
      if (e.type == DioExceptionType.receiveTimeout) {
        debugPrint('⏰ Image generation timed out');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        debugPrint('🌐 Connection timed out');
      }
      return null;
    } catch (e) {
      debugPrint('🔥 Error generating image: $e');
      debugPrint('🔥 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Test method for debugging
  Future<void> testDirectCall() async {
    debugPrint('🧪 Starting direct image generation test...');
    final result = await generateImage('test prompt simple cat');
    debugPrint('🧪 Test result: ${result?.path ?? 'null'}');
  }

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      debugPrint('🔍 Testing image API connection...');
      
      final response = await _dio.post(
        _apiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes, // We expect bytes for image
        ),
        data: jsonEncode({'prompt': 'test connection simple image'}),
      );

      debugPrint('📊 Test response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ API connection successful');
        return true;
      } else {
        debugPrint('❌ API connection failed: ${response.statusCode}');
        debugPrint('❌ Response: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      debugPrint('🔥 Dio error testing connection: ${e.type}');
      debugPrint('🔥 Error message: ${e.message}');
      debugPrint('🔥 Response: ${e.response}');
      return false;
    } catch (e) {
      debugPrint('🔥 API connection error: $e');
      return false;
    }
  }
}
