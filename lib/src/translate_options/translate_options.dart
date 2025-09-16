import 'dart:io';

import 'package:arb_translate/arb_translate.dart';
import 'package:arb_translate/src/translate_options/option_exception.dart';
import 'package:file/file.dart';

/// Enum representing the available model providers.
enum ModelProvider {
  gemini('gemini', 'Gemini'),
  vertexAi('vertex-ai', 'Vertex AI'),
  openAi('open-ai', 'Open AI'),
  openRouter('openrouter', 'OpenRouter'),
  customOpenAiCompatible('custom', 'Custom Open AI compatible');

  const ModelProvider(this.key, this.name);

  final String key;
  final String name;
}

/// Enum representing the available models.
enum Model {
  gemini15Pro('gemini-1.5-pro', 'Gemini 1.5 Pro'),
  gemini15Flash('gemini-1.5-flash', 'Gemini 1.5 Flash'),
  gemini20Flash('gemini-2.0-flash', 'Gemini 2.0 Flash'),
  gemini20FlashLite('gemini-2.0-flash-lite', 'Gemini 2.0 Flash-Lite'),
  gemini25Pro('gemini-2.5-pro', 'Gemini 2.5 Pro'),
  gemini25Flash('gemini-2.5-flash', 'Gemini 2.5 Flash'),
  gemini25FlashLite('gemini-2.5-flash-lite', 'Gemini 2.5 Flash-Lite'),
  gpt35Turbo('gpt-3.5-turbo', 'GPT-3.5 Turbo'),
  gpt4('gpt-4', 'GPT-4'),
  gpt4Turbo('gpt-4-turbo', 'GPT-4 Turbo'),
  gpt4O('gpt-4o', 'GPT-4o'),
  gpt4OMini('gpt-4o-mini', 'GPT-4o mini'),
  // OpenRouter models
  claude35Sonnet('anthropic/claude-3.5-sonnet', 'Claude 3.5 Sonnet'),
  claude3Haiku('anthropic/claude-3-haiku', 'Claude 3 Haiku'),
  openRouterGpt4O('openai/gpt-4o', 'GPT-4o (OpenRouter)'),
  openRouterGemini2Flash(
    'google/gemini-2.0-flash-exp',
    'Gemini 2.0 Flash (OpenRouter)',
  );

  const Model(this.key, this.name);

  final String key;
  final String name;

  List<ModelProvider> get providers {
    if (geminiModels.contains(this)) {
      return [ModelProvider.gemini, ModelProvider.vertexAi];
    } else if (openRouterModels.contains(this)) {
      return [ModelProvider.openRouter];
    } else {
      return [ModelProvider.openAi];
    }
  }

  /// Returns a set of Gemini models.
  static Set<Model> get geminiModels => {
    Model.gemini15Pro,
    Model.gemini15Flash,
    Model.gemini20Flash,
    Model.gemini20FlashLite,
    Model.gemini25Pro,
    Model.gemini25Flash,
    Model.gemini25FlashLite,
  };

  /// Returns a set of GPT models.
  static Set<Model> get gptModels => {
    Model.gpt35Turbo,
    Model.gpt4,
    Model.gpt4Turbo,
    Model.gpt4O,
    Model.gpt4OMini,
  };

  /// Returns a set of OpenRouter models.
  static Set<Model> get openRouterModels => {
    Model.claude35Sonnet,
    Model.claude3Haiku,
    Model.openRouterGpt4O,
    Model.openRouterGemini2Flash,
  };
}

/// Class representing the options for translation.
class TranslateOptions {
  const TranslateOptions({
    required this.modelProvider,
    required this.model,
    required this.customModel,
    required this.apiKey,
    required this.vertexAiProjectUrl,
    required this.customModelProviderBaseUrl,
    required bool? disableSafety,
    required this.context,
    required this.arbDir,
    required String? templateArbFile,
    required this.excludeLocales,
    required this.batchSize,
    required bool? useEscaping,
    required bool? relaxSyntax,
  }) : disableSafety = disableSafety ?? false,
       templateArbFile = templateArbFile ?? 'app_en.arb',
       useEscaping = useEscaping ?? false,
       relaxSyntax = relaxSyntax ?? false;

  static const arbDirKey = 'arb-dir';
  static const templateArbFileKey = 'template-arb-file';
  static const useEscapingKey = 'use-escaping';
  static const relaxSyntaxKey = 'relax-syntax';

  static const maxContextLength = 32768;

  final ModelProvider modelProvider;
  final Model model;
  final String? customModel;
  final String apiKey;
  final Uri? vertexAiProjectUrl;
  final Uri? customModelProviderBaseUrl;
  final bool disableSafety;
  final String? context;
  final String arbDir;
  final String templateArbFile;
  final List<String>? excludeLocales;
  final int batchSize;
  final bool useEscaping;
  final bool relaxSyntax;

  /// Factory method to resolve [TranslateOptions] from command line arguments
  /// and YAML configuration.
  factory TranslateOptions.resolve(
    FileSystem fileSystem,
    TranslateArgResults argResults,
    TranslateYamlResults yamlResults,
  ) {
    final modelProvider =
        argResults.modelProvider ??
        yamlResults.modelProvider ??
        ModelProvider.gemini;

    final apiKey =
        argResults.apiKey ??
        yamlResults.apiKey ??
        _getApiKeyForProvider(modelProvider);

    if (apiKey == null || apiKey.isEmpty) {
      throw MissingApiKeyException();
    }

    final placeholderMatch = RegExp(r'\$\{[^}]+\}').firstMatch(apiKey);
    if (placeholderMatch != null) {
      final placeholder = placeholderMatch.group(0);
      print(
        'WARNING: API key for provider ${modelProvider.name} still contains '
        'placeholder $placeholder. Ensure environment variable '
        '${_getEnvVarName(modelProvider)} is exported in your shell.',
      );
    }

    final model =
        argResults.model ??
        yamlResults.model ??
        _getDefaultModelForProvider(modelProvider);
    final customModel = argResults.customModel ?? yamlResults.customModel;

    if (modelProvider != ModelProvider.customOpenAiCompatible) {
      if (!model.providers.contains(modelProvider)) {
        throw ModelProviderMismatchException();
      }
    } else {
      if (customModel == null) {
        throw MissingCustomModelException();
      }
    }

    if (modelProvider == ModelProvider.customOpenAiCompatible &&
        customModel == null) {
      throw MissingCustomModelException();
    }

    final vertexAiProjectUrlString =
        argResults.vertexAiProjectUrl ?? yamlResults.vertexAiProjectUrl;
    final Uri? vertexAiProjectUrl =
        vertexAiProjectUrlString != null
            ? Uri.tryParse(vertexAiProjectUrlString)
            : null;

    if (modelProvider == ModelProvider.vertexAi) {
      if (vertexAiProjectUrlString == null) {
        throw MissingVertexAiProjectUrlException();
      }

      if (vertexAiProjectUrl == null ||
          vertexAiProjectUrl.scheme != 'https' ||
          !vertexAiProjectUrl.path.endsWith('models')) {
        throw InvalidVertexAiProjectUrlException();
      }
    }

    final customModelProviderBaseUrlString =
        argResults.customModelProviderBaseUrl ??
        yamlResults.customModelProviderBaseUrl;
    final Uri? customModelProviderBaseUrl =
        customModelProviderBaseUrlString != null
            ? Uri.tryParse(customModelProviderBaseUrlString)
            : null;

    if (modelProvider == ModelProvider.customOpenAiCompatible) {
      if (customModelProviderBaseUrlString == null) {
        throw MissingCustomModelProviderBaseUrlException();
      }

      if (customModelProviderBaseUrl == null) {
        throw InvalidCustomModelProviderBaseUrlException();
      }
    }

    final context = argResults.context ?? yamlResults.context;

    if (context != null && context.length > maxContextLength) {
      throw ContextTooLongException();
    }

    return TranslateOptions(
      modelProvider: modelProvider,
      customModelProviderBaseUrl: customModelProviderBaseUrl,
      model: model,
      customModel: customModel,
      apiKey: apiKey,
      vertexAiProjectUrl: vertexAiProjectUrl,
      disableSafety: argResults.disableSafety ?? yamlResults.disableSafety,
      context: context,
      arbDir:
          argResults.arbDir ??
          yamlResults.arbDir ??
          fileSystem.path.join('lib', 'l10n'),
      templateArbFile:
          argResults.templateArbFile ?? yamlResults.templateArbFile,
      excludeLocales: argResults.excludeLocales ?? yamlResults.excludeLocales,
      batchSize: argResults.batchSize ?? yamlResults.batchSize ?? 4096,
      useEscaping: argResults.useEscaping ?? yamlResults.useEscaping,
      relaxSyntax: argResults.relaxSyntax ?? yamlResults.relaxSyntax,
    );
  }

  /// Gets the appropriate API key environment variable for the given provider.
  static String? _getApiKeyForProvider(ModelProvider provider) {
    final key = switch (provider) {
      ModelProvider.gemini ||
      ModelProvider.vertexAi => Platform.environment['GEMINI_API_KEY'],
      ModelProvider.openAi => Platform.environment['OPENAI_API_KEY'],
      ModelProvider.openRouter => Platform.environment['OPENROUTER_API_KEY'],
      ModelProvider.customOpenAiCompatible =>
        Platform.environment['ARB_TRANSLATE_API_KEY'],
    };
    final envName = _getEnvVarName(provider);
    if (key == null || key.isEmpty) {
      print(
        'arb_translate: No API key found for provider ${provider.name} '
        '(env $envName).',
      );
    } else {
      print(
        'arb_translate: Resolved API key for provider ${provider.name} '
        '(env $envName) length=${key.length}, preview=${_maskKey(key)}',
      );
    }
    return key;
  }

  static String _getEnvVarName(ModelProvider provider) {
    return switch (provider) {
      ModelProvider.gemini || ModelProvider.vertexAi => 'GEMINI_API_KEY',
      ModelProvider.openAi => 'OPENAI_API_KEY',
      ModelProvider.openRouter => 'OPENROUTER_API_KEY',
      ModelProvider.customOpenAiCompatible => 'ARB_TRANSLATE_API_KEY',
    };
  }

  static String _maskKey(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
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

  /// Gets the default model for the given provider.
  static Model _getDefaultModelForProvider(ModelProvider provider) {
    return switch (provider) {
      ModelProvider.gemini || ModelProvider.vertexAi => Model.gemini25Flash,
      ModelProvider.openAi => Model.gpt35Turbo,
      ModelProvider.openRouter => Model.claude35Sonnet,
      ModelProvider.customOpenAiCompatible => Model.gpt35Turbo,
    };
  }
}
