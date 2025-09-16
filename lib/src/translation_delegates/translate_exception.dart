sealed class TranslateException implements Exception {
  String get message;
}

class InvalidApiKeyException implements TranslateException {
  InvalidApiKeyException({
    this.provider,
    this.environmentVariable,
    this.keyPreview,
    this.keyLength,
  });

  final String? provider;
  final String? environmentVariable;
  final String? keyPreview;
  final int? keyLength;

  @override
  String get message {
    final buffer = StringBuffer('Provided API key is not valid');
    if (provider != null) {
      buffer.write(' for $provider');
    }
    if (environmentVariable != null) {
      buffer.write(' (env $environmentVariable)');
    }
    if (keyLength != null) {
      buffer.write(', length=$keyLength');
    }
    if (keyPreview != null && keyPreview!.isNotEmpty) {
      buffer.write(', preview=$keyPreview');
    }
    return buffer.toString();
  }
}

class UnsupportedUserLocationException implements TranslateException {
  @override
  String get message =>
      'Gemini API is not available in your location. Use '
      'Vertex AI model provider. See the documentation for more information';
}

class SafetyException implements TranslateException {
  @override
  String get message =>
      'Translation failed due to safety settings. You can disable safety '
      'settings using --disable-safety flag or with '
      'arb-translate-disable-safety: true in l10n.yaml';
}

class QuotaExceededException implements TranslateException {
  @override
  String get message => 'Quota exceeded';
}

class NoResponseException implements TranslateException {
  @override
  String get message => 'Failed to get a response from the model';
}

class ResponseParsingException implements TranslateException {
  @override
  String get message => 'Failed to parse API response';
}

class PlaceholderValidationException implements TranslateException {
  @override
  String get message => 'Placeholder validation failed';
}
