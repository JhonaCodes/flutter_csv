import 'csv_settings.dart';

/// Result of CSV settings detection
final class DetectionResult {
  const DetectionResult({
    required this.settings,
    this.needMoreData = false,
    this.confidence = 1.0,
  });
  final CsvSettings settings;
  final bool needMoreData;
  final double confidence;
}

/// Abstract interface for CSV settings detection strategies
abstract interface class SettingsDetector {
  DetectionResult detect(String csvSample);
}

/// Detects CSV settings by finding the first occurrence of possible delimiters
final class FirstOccurrenceDetector implements SettingsDetector {
  const FirstOccurrenceDetector({
    this.fieldDelimiters = const [',', ';', '\t', '|'],
    this.textDelimiters = const ['"', "'"],
    this.eols = const ['\r\n', '\n', '\r'],
  });
  final List<String> fieldDelimiters;
  final List<String> textDelimiters;
  final List<String> eols;

  @override
  DetectionResult detect(String csvSample) {
    if (csvSample.isEmpty) {
      return const DetectionResult(
        settings: CsvSettings(),
        needMoreData: true,
        confidence: 0.0,
      );
    }

    final detectedField = _findFirstOccurrence(csvSample, fieldDelimiters);
    final detectedText = _findFirstOccurrence(csvSample, textDelimiters);
    final detectedEol = _findFirstOccurrence(csvSample, eols);

    return DetectionResult(
      settings: CsvSettings(
        fieldDelimiter: detectedField ?? ',',
        textDelimiter: detectedText ?? '"',
        eol: detectedEol ?? '\n',
      ),
      confidence:
          _calculateConfidence(detectedField, detectedText, detectedEol),
    );
  }

  String? _findFirstOccurrence(String text, List<String> candidates) {
    int minIndex = -1;
    String? found;

    for (final candidate in candidates) {
      final index = text.indexOf(candidate);
      if (index >= 0 && (minIndex < 0 || index < minIndex)) {
        minIndex = index;
        found = candidate;
      }
    }

    return found;
  }

  double _calculateConfidence(String? field, String? text, String? eol) {
    var score = 0.0;
    if (field != null) score += 0.4;
    if (text != null) score += 0.3;
    if (eol != null) score += 0.3;
    return score;
  }
}

/// Smart detector that analyzes CSV structure patterns
final class SmartSettingsDetector implements SettingsDetector {
  const SmartSettingsDetector({
    this.fieldDelimiters = const [',', ';', '\t', '|'],
    this.textDelimiters = const ['"', "'"],
    this.eols = const ['\r\n', '\n', '\r'],
  });
  final List<String> fieldDelimiters;
  final List<String> textDelimiters;
  final List<String> eols;

  @override
  DetectionResult detect(String csvSample) {
    if (csvSample.isEmpty) {
      return const DetectionResult(
        settings: CsvSettings(),
        needMoreData: true,
        confidence: 0.0,
      );
    }

    // Detect EOL first
    final eol = _detectEol(csvSample);
    final lines = csvSample.split(eol);

    // Detect field delimiter by consistency across lines
    final fieldDelimiter = _detectFieldDelimiter(lines);

    // Detect text delimiter
    final textDelimiter = _detectTextDelimiter(csvSample);

    final confidence = _calculateConfidence(lines, fieldDelimiter);

    return DetectionResult(
      settings: CsvSettings(
        fieldDelimiter: fieldDelimiter,
        textDelimiter: textDelimiter,
        eol: eol,
      ),
      confidence: confidence,
    );
  }

  String _detectEol(String text) {
    // Check for CRLF first (Windows)
    if (text.contains('\r\n')) return '\r\n';
    // Then CR (old Mac)
    if (text.contains('\r')) return '\r';
    // Default to LF (Unix/modern Mac)
    return '\n';
  }

  String _detectFieldDelimiter(List<String> lines) {
    if (lines.length < 2) {
      return _findMostCommon(lines.firstOrNull ?? '', fieldDelimiters) ?? ',';
    }

    // Count occurrences per line for each delimiter
    final scores = <String, int>{};

    for (final delimiter in fieldDelimiters) {
      final counts = lines
          .where((line) => line.isNotEmpty)
          .map((line) => _countOccurrences(line, delimiter))
          .toList();

      if (counts.isEmpty) continue;

      // Check if count is consistent across lines
      final firstCount = counts.first;
      if (firstCount > 0 && counts.every((c) => c == firstCount)) {
        scores[delimiter] = firstCount * 10; // Bonus for consistency
      } else {
        scores[delimiter] = counts.fold(0, (a, b) => a + b);
      }
    }

    return scores.entries
            .where((e) => e.value > 0)
            .fold<MapEntry<String, int>?>(
              null,
              (best, e) => best == null || e.value > best.value ? e : best,
            )
            ?.key ??
        ',';
  }

  String _detectTextDelimiter(String text) {
    for (final delimiter in textDelimiters) {
      if (text.contains(delimiter)) return delimiter;
    }
    return '"';
  }

  String? _findMostCommon(String text, List<String> candidates) {
    int maxCount = 0;
    String? found;

    for (final candidate in candidates) {
      final count = _countOccurrences(text, candidate);
      if (count > maxCount) {
        maxCount = count;
        found = candidate;
      }
    }

    return found;
  }

  int _countOccurrences(String text, String pattern) {
    if (pattern.isEmpty) return 0;
    var count = 0;
    var index = 0;
    while ((index = text.indexOf(pattern, index)) >= 0) {
      count++;
      index += pattern.length;
    }
    return count;
  }

  double _calculateConfidence(List<String> lines, String delimiter) {
    if (lines.length < 2) return 0.5;

    final counts = lines
        .where((line) => line.isNotEmpty)
        .map((line) => _countOccurrences(line, delimiter))
        .toList();

    if (counts.isEmpty) return 0.3;

    final firstCount = counts.first;
    final consistentLines = counts.where((c) => c == firstCount).length;

    return consistentLines / counts.length;
  }
}
