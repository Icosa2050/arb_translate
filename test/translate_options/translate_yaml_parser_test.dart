import 'dart:io';

import 'package:arb_translate/src/translate_options/translate_yaml_parser.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  group('TranslateYamlParser', () {
    late MemoryFileSystem fileSystem;
    late TranslateYamlParser parser;

    setUp(() {
      fileSystem = MemoryFileSystem();
      parser = TranslateYamlParser();
    });

    group('environment variable expansion', () {
      test('expands environment variables that exist', () {
        // Use PATH which should exist on all systems
        final pathValue = Platform.environment['PATH'];
        
        if (pathValue != null) {
          final yamlContent = '''
arb-translate-context: "Path is: \${PATH}"
''';

          final file = fileSystem.file('test.yaml');
          file.writeAsStringSync(yamlContent);

          final result = parser.parse(file);

          expect(result.context, equals('Path is: $pathValue'));
        }
      });

      test('keeps literal when environment variable does not exist', () {
        const nonExistentVar = 'NON_EXISTENT_VAR_DEFINITELY_NOT_SET_12345';

        final yamlContent = '''
arb-translate-api-key: \${$nonExistentVar}
''';

        final file = fileSystem.file('test.yaml');
        file.writeAsStringSync(yamlContent);

        final result = parser.parse(file);

        expect(result.apiKey, equals('\${$nonExistentVar}'));
      });

      test('handles multiple variables - some exist, some don\'t', () {
        const existingVar = 'HOME'; // Should exist on most systems
        const nonExistentVar = 'NON_EXISTENT_VAR_12345';
        
        final homeValue = Platform.environment[existingVar];
        if (homeValue != null) {
          final yamlContent = '''
arb-translate-context: "Home: \${$existingVar}, Missing: \${$nonExistentVar}"
''';

          final file = fileSystem.file('test.yaml');
          file.writeAsStringSync(yamlContent);

          final result = parser.parse(file);

          expect(result.context, equals('Home: $homeValue, Missing: \${$nonExistentVar}'));
        }
      });

      test('handles empty braces syntax', () {
        final yamlContent = '''
arb-translate-context: "Invalid \${} and \${  } syntax"
''';

        final file = fileSystem.file('test.yaml');
        file.writeAsStringSync(yamlContent);

        final result = parser.parse(file);

        expect(result.context, equals('Invalid \${} and \${  } syntax'));
      });

      test('handles no environment variables in string', () {
        final yamlContent = '''
arb-translate-context: "Just a regular string"
''';

        final file = fileSystem.file('test.yaml');
        file.writeAsStringSync(yamlContent);

        final result = parser.parse(file);

        expect(result.context, equals('Just a regular string'));
      });

      test('expansion works for API key field specifically', () {
        const nonExistentKey = 'FAKE_API_KEY_FOR_TEST_12345';

        final yamlContent = '''
arb-translate-api-key: \${$nonExistentKey}
arb-translate-context: "Test context"
''';

        final file = fileSystem.file('test.yaml');
        file.writeAsStringSync(yamlContent);

        final result = parser.parse(file);

        expect(result.apiKey, equals('\${$nonExistentKey}'));
        expect(result.context, equals('Test context'));
      });
    });

    test('handles empty file', () {
      final file = fileSystem.file('empty.yaml');
      file.writeAsStringSync('');

      final result = parser.parse(file);

      expect(result.apiKey, isNull);
      expect(result.modelProvider, isNull);
    });

    test('handles non-existent file', () {
      final file = fileSystem.file('non-existent.yaml');

      final result = parser.parse(file);

      expect(result.apiKey, isNull);
      expect(result.modelProvider, isNull);
    });

    test('handles normal YAML without environment variables', () {
      final yamlContent = '''
arb-translate-model-provider: gemini
arb-translate-context: "Normal context"
''';

      final file = fileSystem.file('normal.yaml');
      file.writeAsStringSync(yamlContent);

      final result = parser.parse(file);

      expect(result.context, equals('Normal context'));
    });
  });
}