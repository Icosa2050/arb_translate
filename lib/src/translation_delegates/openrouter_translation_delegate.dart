import 'dart:convert';

import 'package:arb_translate/src/flutter_tools/localizations_utils.dart';
import 'package:arb_translate/src/translate_options/translate_options.dart';
import 'package:arb_translate/src/translation_delegates/translate_exception.dart';
import 'package:arb_translate/src/translation_delegates/translation_delegate.dart';
import 'package:http/http.dart' as http;

class OpenRouterTranslationDelegate extends TranslationDelegate {
  OpenRouterTranslationDelegate({
    required Model model,
    required String apiKey,
    required super.batchSize,
    required super.context,
    required super.useEscaping,
    required super.relaxSyntax,
  }) : _model = model.key,
       _apiKey = apiKey {
    final preview = _maskKey(apiKey);
    print(
      'arb_translate: OpenRouter API key resolved (env OPENROUTER_API_KEY) '
      'length=${apiKey.length}, preview=$preview',
    );
    print('arb_translate: Using model ${model.key}');
  }

  @override
  int get maxRetryCount => 5;
  @override
  int get maxParallelQueries => 3; // OpenRouter has rate limits
  @override
  Duration get queryBackoff => Duration(seconds: 2);

  final String _model;
  final String _apiKey;

  @override
  Future<String> getModelResponse(
    Map<String, Object?> resources,
    LocaleInfo locale,
  ) async {
    final encodedResources = JsonEncoder.withIndent('  ').convert(resources);

    final systemPrompt =
        'You are a professional translator specializing in app localization. '
        'Translate ARB messages for ${context ?? 'app'} to locale "$locale". '
        'Add other ICU plural forms according to CLDR rules if necessary. '
        'Return only raw JSON without markdown formatting or explanations.';

    final userPrompt = 'Translate this ARB content:\n\n$encodedResources';

    final requestBody = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.1,
      'max_tokens': 4000,
    };

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/leancodepl/arb_translate',
          'X-Title': 'ARB Translate Tool',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 401) {
        throw InvalidApiKeyException(
          provider: 'OpenRouter',
          environmentVariable: 'OPENROUTER_API_KEY',
          keyPreview: _maskKey(_apiKey),
          keyLength: _apiKey.length,
        );
      }

      if (response.statusCode == 429) {
        throw QuotaExceededException();
      }

      if (response.statusCode != 200) {
        throw Exception(
          'OpenRouter API error: ${response.statusCode} - ${response.body}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (responseData['error'] != null) {
        final error = responseData['error'] as Map<String, dynamic>;
        final errorMessage = error['message'] as String? ?? 'Unknown error';

        if (errorMessage.toLowerCase().contains('quota') ||
            errorMessage.toLowerCase().contains('insufficient')) {
          throw QuotaExceededException();
        }

        throw Exception('OpenRouter error: $errorMessage');
      }

      final choices = responseData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw NoResponseException();
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null || content.trim().isEmpty) {
        throw NoResponseException();
      }

      // Clean up the response to extract just the JSON
      String cleanContent = content.trim();

      // Remove markdown code blocks if present
      if (cleanContent.startsWith('```json')) {
        cleanContent = cleanContent.substring(7);
      }
      if (cleanContent.startsWith('```')) {
        cleanContent = cleanContent.substring(3);
      }
      if (cleanContent.endsWith('```')) {
        cleanContent = cleanContent.substring(0, cleanContent.length - 3);
      }

      return cleanContent.trim();
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      if (e is TranslateException) {
        rethrow;
      }
      print('OpenRouter API error: $e');
      rethrow;
    }
  }
}

String _maskKey(String key) {
  final cleaned = key.replaceAll(RegExp(r'\s+'), '');
  if (cleaned.isEmpty) {
    return '(empty)';
  }
  if (cleaned.length <= 3) {
    return '${cleaned[0]}***';
  }
  if (cleaned.length <= 6) {
    return '${cleaned.substring(0, 2)}***${cleaned.substring(cleaned.length - 1)}';
  }
  final prefix = cleaned.substring(0, 4);
  final suffix = cleaned.substring(cleaned.length - 2);
  return '$prefix...$suffix';
}
