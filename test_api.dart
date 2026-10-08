import 'dart:convert';
import 'dart:io';
import 'dart:async';

void main() async {
  try {
    print('🔍 Testing image generation API...');
    
    final apiUrl = 'https://image-api.atharvgawand2.workers.dev';
    final apiKey = '1234567890';
    
    // Test with basic HTTP
    final httpClient = HttpClient();
    
    final request = await httpClient.postUrl(Uri.parse(apiUrl));
    request.headers.set('Authorization', 'Bearer $apiKey');
    request.headers.set('Content-Type', 'application/json');
    
    final prompt = 'boy playing gta 8';
    final body = jsonEncode({'prompt': prompt});
    
    request.add(utf8.encode(body));
    
    final response = await request.close();
    
    print('📊 Status code: ${response.statusCode}');
    print('📊 Headers: ${response.headers}');
    
    // Read response as bytes
    final List<int> responseData = [];
    await for (final chunk in response) {
      responseData.addAll(chunk);
    }
    
    print('📊 Data length: ${responseData.length}');
    print('📊 First 100 bytes: ${responseData.take(100).join(', ')}');
    
    // Save response to file
    final file = File('test_response.dat');
    await file.writeAsBytes(responseData);
    print('📁 Response saved to: ${file.path}');
    
    httpClient.close();
  } catch (e) {
    print('🔥 Error: $e');
  }
}
