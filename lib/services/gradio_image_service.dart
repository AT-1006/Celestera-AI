import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

class GradioImageService {
  static final GradioImageService _instance = GradioImageService._internal();
  factory GradioImageService() => _instance;
  
  final String _gradioUrl = 'https://b5e7bdf571213a909b.gradio.live';
  final Dio _dio = Dio();
  
  GradioImageService._internal() {
    // Configure Dio with timeout
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 120); // Image generation can take time
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  // =============================
  // Basic Image Generation
  // =============================
  
  /// Generate image from text prompt using the main generation endpoint (fn_index=67)
  Future<File?> generateImage(String prompt, {
    String negativePrompt = '',
    List<String> styles = const ['Fooocus V2'],
    String performance = 'Quality',
    String aspectRatio = '704×1408 <span style="color: grey;"> ∣ 1:2</span>',
    int imageNumber = 1,
    String outputFormat = 'png',
    bool randomSeed = true,
    String seed = '',
    double guidanceScale = 7.0,
    double imageSharpness = 0.0,
    String baseModel = 'juggernautXL_v8Rundiffusion.safetensors',
    String refinerModel = 'None',
    double refinerSwitchAt = 0.8,
    bool enableLoRA1 = false,
    String lora1Model = 'None',
    double lora1Weight = 0.0,
    bool enableLoRA2 = false,
    String lora2Model = 'None',
    double lora2Weight = 0.0,
    bool enableLoRA3 = false,
    String lora3Model = 'None',
    double lora3Weight = 0.0,
    bool enableLoRA4 = false,
    String lora4Model = 'None',
    double lora4Weight = 0.0,
    bool enableLoRA5 = false,
    String lora5Model = 'None',
    double lora5Weight = 0.0,
  }) async {
    try {
      debugPrint('🎨 Generating image with Gradio: $prompt');
      
      // Create the data payload for fn_index=67
      final Map<String, dynamic> data = {
        'data': [
          randomSeed, // Random checkbox
          randomSeed ? '' : seed, // Seed textbox
          negativePrompt, // Negative prompt
          styles, // Selected styles
          performance, // Performance
          aspectRatio, // Aspect ratio
          imageNumber, // Image number
          outputFormat, // Output format
          randomSeed ? '' : seed, // Seed (empty if random)
          true, // Read wildcards in order
          imageSharpness, // Image sharpness
          guidanceScale, // Guidance scale
          baseModel, // Base model
          refinerModel, // Refiner model
          refinerSwitchAt, // Refiner switch at
          enableLoRA1, // Enable LoRA 1
          lora1Model, // LoRA 1 model
          lora1Weight, // LoRA 1 weight
          enableLoRA2, // Enable LoRA 2
          lora2Model, // LoRA 2 model
          lora2Weight, // LoRA 2 weight
          enableLoRA3, // Enable LoRA 3
          lora3Model, // LoRA 3 model
          lora3Weight, // LoRA 3 weight
          enableLoRA4, // Enable LoRA 4
          lora4Model, // LoRA 4 model
          lora4Weight, // LoRA 4 weight
          enableLoRA5, // Enable LoRA 5
          lora5Model, // LoRA 5 model
          lora5Weight, // LoRA 5 weight
          false, // Input image checkbox
          '', // Parameter 212
          'Disabled', // Upscale or variation
          '', // Image URL (empty for text generation)
          [], // Outpaint direction
          '', // Image for inpaint
          '', // Inpaint additional prompt
          '', // Mask upload
          true, // Disable preview
          true, // Disable intermediate results
          true, // Disable seed increment
          true, // Black out NSFW
          0.1, // Positive ADM guidance scaler
          0.1, // Negative ADM guidance scaler
          0, // ADM guidance end at step
          1, // CFG mimicking from TSNR
          1, // CLIP skip
          'euler', // Sampler
          'normal', // Scheduler
          'Default (model)', // VAE
          -1, // Forced overwrite sampling step
          -1, // Forced overwrite refiner switch step
          -1, // Forced overwrite width
          -1, // Forced overwrite height
          -1, // Forced overwrite denoising strength vary
          -1, // Forced overwrite denoising strength upscale
          true, // Mixing image prompt and vary/upscale
          true, // Mixing image prompt and inpaint
          true, // Debug preprocessors
          true, // Skip preprocessors
          1, // Canny low threshold
          1, // Canny high threshold
          'joint', // Refiner swap method
          0, // Softness of ControlNet
          true, // Enable ControlNet
          0, // B1
          0, // B2
          0, // S1
          0, // S2
          true, // Debug inpaint preprocessing
          true, // Disable initial latent in inpaint
          'None', // Inpaint engine
          0, // Inpaint denoising strength
          0, // Inpaint respective field
          true, // Enable advanced masking features
          true, // Invert mask when generating
          -64, // Mask erode or dilate
          true, // Save only final enhanced image
          true, // Save metadata to images
          'fooocus', // Metadata scheme
          '', // Image for enhancement
          0, // Stop at
          0, // Weight
          'ImagePrompt', // Type
          '', // Image URL 1
          0, // Stop at 1
          0, // Weight 1
          'ImagePrompt', // Type 1
          '', // Image URL 2
          0, // Stop at 2
          0, // Weight 2
          'ImagePrompt', // Type 2
          '', // Image URL 3
          0, // Stop at 3
          0, // Weight 3
          'ImagePrompt', // Type 3
          '', // Image URL 4
          0, // Stop at 4
          0, // Weight 4
          true, // Debug GroundingDINO
          -64, // GroundingDINO box erode or dilate
          true, // Debug enhance masks
          '', // Use with enhance image
          true, // Enhance checkbox
          'Disabled', // Upscale or variation enhance
          'Before First Enhancement', // Order of processing
          'Original Prompts', // Prompt radio
          true, // Enable detection 1
          '', // Detection prompt 1
          '', // Enhancement positive prompt 1
          '', // Enhancement negative prompt 1
          'u2net', // Mask generation model 1
          'full', // Cloth category 1
          'vit_b', // SAM model 1
          0, // Text threshold 1
          0, // Box threshold 1
          0, // Maximum detections 1
          true, // Disable initial latent 1
          'None', // Inpaint engine 1
          0, // Inpaint denoising strength 1
          0, // Inpaint respective field 1
          -64, // Mask erode or dilate 1
          true, // Invert mask 1
          true, // Enable detection 2
          '', // Detection prompt 2
          '', // Enhancement positive prompt 2
          '', // Enhancement negative prompt 2
          'u2net', // Mask generation model 2
          'full', // Cloth category 2
          'vit_b', // SAM model 2
          0, // Text threshold 2
          0, // Box threshold 2
          0, // Maximum detections 2
          true, // Disable initial latent 2
          'None', // Inpaint engine 2
          0, // Inpaint denoising strength 2
          0, // Inpaint respective field 2
          -64, // Mask erode or dilate 2
          true, // Invert mask 2
          true, // Enable detection 3
          '', // Detection prompt 3
          '', // Enhancement positive prompt 3
          '', // Enhancement negative prompt 3
          'u2net', // Mask generation model 3
          'full', // Cloth category 3
          'vit_b', // SAM model 3
          0, // Text threshold 3
          0, // Box threshold 3
          0, // Maximum detections 3
          true, // Disable initial latent 3
          'None', // Inpaint engine 3
          0, // Inpaint denoising strength 3
          0, // Inpaint respective field 3
          -64, // Mask erode or dilate 3
          true, // Invert mask 3
        ],
        'fn_index': 67,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );

      debugPrint('✅ Image generation completed');
      
      // Process the result to extract image data
      if (response.statusCode == 200 && response.data != null) {
        return await _processGradioResult(response.data, prompt);
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error generating image: $e');
      return null;
    }
  }

  // =============================
  // Image Editing Functions
  // =============================
  
  /// Inpaint or outpaint an image
  Future<File?> inpaintImage({
    required File inputImage,
    String additionalPrompt = '',
    List<String> outpaintDirections = const [],
    String method = 'Inpaint or Outpaint (default)',
    String inpaintEngine = 'None',
    double inpaintDenoisingStrength = 0.0,
    double inpaintRespectiveField = 0.0,
    bool disableInitialLatent = true,
    File? maskImage,
  }) async {
    try {
      debugPrint('🎨 Inpainting image with Gradio');
      
      // Convert images to base64 or upload
      String inputImageUrl = await _convertImageToBase64(inputImage);
      String? maskImageUrl = maskImage != null ? await _convertImageToBase64(maskImage) : null;
      
      final Map<String, dynamic> data = {
        'data': [
          method, // Method dropdown
          additionalPrompt, // Inpaint additional prompt
          outpaintDirections, // Outpaint direction
          disableInitialLatent, // Disable initial latent in inpaint
          inpaintEngine, // Inpaint engine
          inpaintDenoisingStrength, // Inpaint denoising strength
          inpaintRespectiveField, // Inpaint respective field
        ],
        'fn_index': 55,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200 && response.data != null) {
        return await _processGradioResult(response.data, 'inpaint');
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error inpainting image: $e');
      return null;
    }
  }

  /// Enhance image quality
  Future<File?> enhanceImage({
    required File inputImage,
    String positivePrompt = '',
    String negativePrompt = '',
    String maskModel = 'u2net',
    String clothCategory = 'full',
    String samModel = 'vit_b',
    double textThreshold = 0.0,
    double boxThreshold = 0.0,
    int maxDetections = 0,
    bool disableInitialLatent = true,
    String inpaintEngine = 'None',
    double inpaintDenoisingStrength = 0.0,
    double inpaintRespectiveField = 0.0,
    int maskErodeDilate = -64,
    bool invertMask = true,
  }) async {
    try {
      debugPrint('✨ Enhancing image with Gradio');
      
      String inputImageUrl = await _convertImageToBase64(inputImage);
      
      final Map<String, dynamic> data = {
        'data': [
          true, // Enable checkbox
          positivePrompt, // Detection prompt
          positivePrompt, // Enhancement positive prompt
          negativePrompt, // Enhancement negative prompt
          maskModel, // Mask generation model
          clothCategory, // Cloth category
          samModel, // SAM model
          textThreshold, // Text threshold
          boxThreshold, // Box threshold
          maxDetections, // Maximum detections
          disableInitialLatent, // Disable initial latent
          inpaintEngine, // Inpaint engine
          inpaintDenoisingStrength, // Inpaint denoising strength
          inpaintRespectiveField, // Inpaint respective field
          maskErodeDilate, // Mask erode or dilate
          invertMask, // Invert mask
        ],
        'fn_index': 67, // Using main generation endpoint with enhancement
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200 && response.data != null) {
        return await _processGradioResult(response.data, 'enhance');
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error enhancing image: $e');
      return null;
    }
  }

  /// Generate mask from image
  Future<File?> generateMask({
    required File inputImage,
    String maskModel = 'u2net',
    String clothCategory = 'full',
    String detectionPrompt = '',
    String samModel = 'vit_b',
    double boxThreshold = 0.0,
    double textThreshold = 0.0,
    int maxDetections = 0,
    int groundDinoErodeDilate = -64,
    bool debugGroundingDINO = true,
  }) async {
    try {
      debugPrint('🎭 Generating mask with Gradio');
      
      String inputImageUrl = await _convertImageToBase64(inputImage);
      
      final Map<String, dynamic> data = {
        'data': [
          inputImageUrl, // Image
          maskModel, // Mask generation model
          clothCategory, // Cloth category
          detectionPrompt, // Detection prompt
          samModel, // SAM model
          boxThreshold, // Box threshold
          textThreshold, // Text threshold
          maxDetections, // Maximum detections
          groundDinoErodeDilate, // GroundingDINO box erode or dilate
          debugGroundingDINO, // Debug GroundingDINO
        ],
        'fn_index': 60,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200 && response.data != null) {
        return await _processGradioResult(response.data, 'mask');
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error generating mask: $e');
      return null;
    }
  }

  // =============================
  // Utility Functions
  // =============================
  
  /// Convert File to base64 for Gradio
  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64 = base64Encode(bytes);
      return 'data:image/png;base64,$base64';
    } catch (e) {
      debugPrint('❌ Error converting image to base64: $e');
      return '';
    }
  }
  
  /// Process Gradio result and save as file
  Future<File?> _processGradioResult(dynamic result, String operation) async {
    try {
      debugPrint('🔄 Processing Gradio result for $operation');
      
      // Gradio typically returns image data as file paths or base64
      if (result is Map && result['data'] != null) {
        final data = result['data'];
        if (data is List && data.isNotEmpty) {
          final firstResult = data[0];
          
          if (firstResult is Map && firstResult['image'] != null) {
            // Handle image object with URL/path
            String imagePath = firstResult['image']['url'] ?? firstResult['image']['path'] ?? '';
            
            if (imagePath.startsWith('http')) {
              return await _downloadImageFromUrl(imagePath, operation);
            } else if (File(imagePath).existsSync()) {
              final tempDir = Directory.systemTemp;
              final fileName = '${operation}_${DateTime.now().millisecondsSinceEpoch}.png';
              final newFile = File('${tempDir.path}/$fileName');
              
              await File(imagePath).copy(newFile.path);
              debugPrint('📁 Image saved to: ${newFile.path}');
              return newFile;
            }
          } else if (firstResult is String) {
            // Handle direct base64 string
            if (firstResult.startsWith('data:image')) {
              return await _saveBase64Image(firstResult, operation);
            }
          }
        }
      }
      
      debugPrint('❌ Could not process image result: $result');
      return null;
    } catch (e) {
      debugPrint('❌ Error processing Gradio result: $e');
      return null;
    }
  }
  
  /// Save base64 image to file
  Future<File?> _saveBase64Image(String base64String, String operation) async {
    try {
      // Remove data URL prefix if present
      String base64 = base64String;
      if (base64.startsWith('data:image/')) {
        final commaIndex = base64.indexOf(',');
        if (commaIndex != -1) {
          base64 = base64.substring(commaIndex + 1);
        }
      }
      
      final bytes = base64Decode(base64);
      final tempDir = Directory.systemTemp;
      final fileName = '${operation}_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File('${tempDir.path}/$fileName');
      
      await imageFile.writeAsBytes(bytes);
      debugPrint('📁 Base64 image saved to: ${imageFile.path}');
      return imageFile;
    } catch (e) {
      debugPrint('❌ Error saving base64 image: $e');
      return null;
    }
  }
  
  /// Download image from URL
  Future<File?> _downloadImageFromUrl(String url, String operation) async {
    try {
      debugPrint('🌐 Downloading image from: $url');
      
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        final tempDir = Directory.systemTemp;
        final fileName = '${operation}_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File('${tempDir.path}/$fileName');
        
        await imageFile.writeAsBytes(response.data);
        debugPrint('📁 Image downloaded and saved to: ${imageFile.path}');
        return imageFile;
      } else {
        debugPrint('❌ Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error downloading image: $e');
      return null;
    }
  }

  // =============================
  // Advanced Functions (using other fn_index endpoints)
  // =============================
  
  /// Get available styles
  Future<List<String>> getAvailableStyles() async {
    try {
      final Map<String, dynamic> data = {
        'data': [],
        'fn_index': 35,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data is List) {
          return List<String>.from(data);
        }
      }
      return ['Fooocus V2']; // Default fallback
    } catch (e) {
      debugPrint('❌ Error getting styles: $e');
      return ['Fooocus V2'];
    }
  }
  
  /// Get available models
  Future<Map<String, List<String>>> getAvailableModels() async {
    try {
      final Map<String, dynamic> data = {
        'data': [],
        'fn_index': 46,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data is List && data.length >= 3) {
          return {
            'baseModels': List<String>.from(data[0] ?? []),
            'refinerModels': List<String>.from(data[1] ?? []),
            'vaeModels': List<String>.from(data[2] ?? []),
          };
        }
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error getting models: $e');
      return {};
    }
  }
  
  /// Get image metadata
  Future<Map<String, dynamic>?> getImageMetadata(File imageFile) async {
    try {
      String imageUrl = await _convertImageToBase64(imageFile);
      
      final Map<String, dynamic> data = {
        'data': [imageUrl],
        'fn_index': 11,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['data'] is Map) {
          return Map<String, dynamic>.from(response.data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting image metadata: $e');
      return null;
    }
  }
  
  /// Set performance preset
  Future<void> setPerformancePreset(String preset) async {
    try {
      final Map<String, dynamic> data = {
        'data': [
          preset,
          'Inpaint or Outpaint (default)',
        ],
        'fn_index': 47,
      };
      
      await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );
      
      debugPrint('✅ Performance preset set to: $preset');
    } catch (e) {
      debugPrint('❌ Error setting performance preset: $e');
    }
  }
  
  /// Test connection to Gradio API
  Future<bool> testConnection() async {
    try {
      final Map<String, dynamic> data = {
        'data': [],
        'fn_index': 0,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Gradio API connection successful');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Gradio API connection failed: $e');
      return false;
    }
  }
  
  /// Get current generation progress/status
  Future<Map<String, dynamic>?> getGenerationStatus() async {
    try {
      final Map<String, dynamic> data = {
        'data': [],
        'fn_index': 68,
      };
      
      final response = await _dio.post(
        '$_gradioUrl/api/predict',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(data),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['data'] is Map) {
          return Map<String, dynamic>.from(response.data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting generation status: $e');
      return null;
    }
  }
}
