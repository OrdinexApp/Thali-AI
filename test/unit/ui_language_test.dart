import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Scans user-facing Dart source for vendor/model name leaks.
///
/// Rationale: the app wraps a third-party inference service, but end users
/// should never see its name, model identifier, or HTTP-level details. If
/// someone adds a debug string or error message that mentions "Gemini",
/// "Google", "OpenAI", etc. to a presentation-layer file, this test catches
/// it before it ships.
///
/// Scope: only `lib/features/**/presentation/**/*.dart` + `lib/services/providers.dart`.
/// Those are the files whose string literals end up on the screen.
/// Service-layer files (gemini_service.dart) may reference vendors in class
/// names and debug prints — users never see those.
void main() {
  // Case-insensitive, but checked only against extracted string literals
  // so symbol names like `GeminiService` don't trigger false positives.
  final forbidden = <RegExp>[
    RegExp(r'\bgemini\b', caseSensitive: false),
    RegExp(r'\bgoogle\b', caseSensitive: false),
    RegExp(r'\bopenai\b', caseSensitive: false),
    RegExp(r'\bgpt[- ]?[0-9]', caseSensitive: false),
    RegExp(r'\banthropic\b', caseSensitive: false),
    RegExp(r'\bclaude\b', caseSensitive: false),
  ];

  // We scan everything in lib/features/**/presentation/ plus providers.dart,
  // since those are the only paths whose string literals reach the UI.
  final roots = <Directory>[
    Directory('lib/features'),
    Directory('lib/core/widgets'),
    Directory('lib/core/constants'),
  ];

  // Extra files (non-presentation) whose string literals can surface as
  // error text on screen.
  final extraFiles = <File>[
    File('lib/services/providers.dart'),
  ];

  /// Matches Dart single/double-quoted string literals. Not perfect for all
  /// edge cases (raw strings, triple-quoted) but covers everything a UI
  /// string would use in practice.
  final stringLiteralRe = RegExp(
    r'''"([^"\\]|\\.)*"|'([^'\\]|\\.)*'|"""([^"\\]|\\.)*"""''',
    multiLine: true,
  );

  /// Allow-list: these literals are legitimate and NOT user-visible.
  /// Keep this list tight — every entry should have a comment justifying it.
  bool isAllowed(String file, String literal) {
    final lower = literal.toLowerCase();
    // Google Fonts is an industry-standard font package name. Users see only
    // the resulting font family ("Inter"), never the package name.
    if (lower.contains('google_fonts')) return true;
    return false;
  }

  /// Files we don't scan at all: pure config whose literals never surface.
  bool isSkippedFile(String path) {
    // API endpoint config — model identifier is needed for the HTTP URL,
    // never displayed. Keep under a comment for reviewer context.
    if (path.endsWith('api_config.dart') ||
        path.endsWith('api_config.template.dart')) {
      return true;
    }
    return false;
  }

  test('no vendor or model identifiers leak into user-visible strings', () {
    final offenders = <String>[];

    void scanFile(File file) {
      if (!file.existsSync()) return;
      if (isSkippedFile(file.path)) return;
      final contents = file.readAsStringSync();
      final lines = contents.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip pure-comment lines.
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///') ||
            trimmed.startsWith('*')) {
          continue;
        }

        for (final match in stringLiteralRe.allMatches(line)) {
          final literal = match.group(0) ?? '';
          if (isAllowed(file.path, literal)) continue;
          for (final re in forbidden) {
            if (re.hasMatch(literal)) {
              offenders.add(
                '${file.path}:${i + 1}  ${literal.trim()}',
              );
            }
          }
        }
      }
    }

    void scanDir(Directory d) {
      if (!d.existsSync()) return;
      for (final entity in d.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          scanFile(entity);
        }
      }
    }

    for (final root in roots) {
      scanDir(root);
    }
    for (final f in extraFiles) {
      scanFile(f);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'User-visible string literals must stay vendor-neutral.\n'
          'Found references:\n  ${offenders.join('\n  ')}',
    );
  });
}
