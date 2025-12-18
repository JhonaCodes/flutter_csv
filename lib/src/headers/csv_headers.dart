import '../settings/csv_settings.dart';

/// Result of header detection
final class CsvHeaderDetection {
  const CsvHeaderDetection({
    required this.isHeader,
    required this.confidence,
    this.headers,
    this.reasons = const [],
  });

  /// Whether the first row is likely a header
  final bool isHeader;

  /// Confidence level (0.0 to 1.0)
  final double confidence;

  /// Detected headers (null if not a header)
  final List<String>? headers;

  /// Reasons for the detection result
  final List<String> reasons;

  @override
  String toString() =>
      'CsvHeaderDetection(isHeader: $isHeader, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Detects whether the first row of CSV data is a header row
final class CsvHeaderDetector {
  const CsvHeaderDetector({this.settings = const CsvSettings()});
  final CsvSettings settings;

  /// Analyzes data to detect if first row is a header
  CsvHeaderDetection detect(List<List<Object?>> data) {
    if (data.isEmpty) {
      return const CsvHeaderDetection(
        isHeader: false,
        confidence: 1.0,
        reasons: ['No data to analyze'],
      );
    }

    if (data.length == 1) {
      return const CsvHeaderDetection(
        isHeader: false,
        confidence: 0.5,
        reasons: ['Only one row - cannot determine if header'],
      );
    }

    final firstRow = data.first;
    final dataRows = data.skip(1).toList();

    final reasons = <String>[];
    var score = 0.0;
    var checks = 0;

    // Check 1: All first row values are strings
    final allStrings = firstRow.every((v) => v is String);
    if (allStrings) {
      score += 0.2;
      reasons.add('All first row values are strings');
    }
    checks++;

    // Check 2: First row has unique values
    final uniqueValues = firstRow.whereType<String>().toSet();
    if (uniqueValues.length == firstRow.length) {
      score += 0.2;
      reasons.add('First row values are unique');
    }
    checks++;

    // Check 3: First row values look like headers (no numbers, typical patterns)
    final headerPatterns = _checkHeaderPatterns(firstRow);
    if (headerPatterns > 0.5) {
      score += 0.2;
      reasons.add('First row matches header naming patterns');
    }
    checks++;

    // Check 4: Data rows have different types than first row
    final typeDifference = _calculateTypeDifference(firstRow, dataRows);
    if (typeDifference > 0.5) {
      score += 0.2;
      reasons.add('Data rows have different types than first row');
    }
    checks++;

    // Check 5: First row doesn't contain numbers (when data does)
    final firstRowHasNumbers = firstRow.any(_looksLikeNumber);
    final dataHasNumbers = dataRows.any((row) => row.any(_looksLikeNumber));
    if (!firstRowHasNumbers && dataHasNumbers) {
      score += 0.2;
      reasons.add('First row has no numbers while data rows do');
    }
    checks++;

    final confidence = score / (checks * 0.2);
    final isHeader = confidence >= 0.6;

    return CsvHeaderDetection(
      isHeader: isHeader,
      confidence: confidence,
      headers:
          isHeader ? firstRow.map((e) => e?.toString() ?? '').toList() : null,
      reasons: reasons,
    );
  }

  double _checkHeaderPatterns(List<Object?> row) {
    var matches = 0;
    final patterns = [
      RegExp(r'^[a-zA-Z][a-zA-Z0-9_\s]*$'), // Starts with letter
      RegExp(r'^[A-Z][a-z]+$'), // Capitalized word
      RegExp(r'^[a-z]+_[a-z]+$'), // snake_case
      RegExp(r'^[a-z]+[A-Z][a-z]+$'), // camelCase
      RegExp(r'^[A-Z]+$'), // ALL_CAPS
    ];

    for (final value in row) {
      final str = value?.toString() ?? '';
      if (str.isEmpty) continue;

      for (final pattern in patterns) {
        if (pattern.hasMatch(str)) {
          matches++;
          break;
        }
      }
    }

    return row.isEmpty ? 0.0 : matches / row.length;
  }

  double _calculateTypeDifference(
      List<Object?> firstRow, List<List<Object?>> dataRows) {
    if (dataRows.isEmpty) return 0.0;

    var differences = 0;
    var comparisons = 0;

    for (var col = 0; col < firstRow.length; col++) {
      final firstType = _getValueType(firstRow[col]);

      for (final row in dataRows) {
        if (col >= row.length) continue;
        final dataType = _getValueType(row[col]);
        comparisons++;

        if (firstType != dataType) {
          differences++;
        }
      }
    }

    return comparisons == 0 ? 0.0 : differences / comparisons;
  }

  String _getValueType(Object? value) => switch (value) {
        null => 'null',
        final String s when _looksLikeNumber(s) => 'number',
        String _ => 'string',
        int _ => 'number',
        double _ => 'number',
        bool _ => 'bool',
        _ => 'other',
      };

  bool _looksLikeNumber(Object? value) {
    if (value == null) return false;
    if (value is num) return true;
    if (value is! String) return false;

    final str = value.trim();
    if (str.isEmpty) return false;

    // Try parsing with current decimal separator
    var normalized = str;
    if (settings.decimalSeparator != '.') {
      normalized = str.replaceAll(settings.decimalSeparator, '.');
    }

    return int.tryParse(normalized) != null ||
        double.tryParse(normalized) != null;
  }
}

/// Utility class for header manipulation
final class CsvHeaders {
  const CsvHeaders._();

  /// Generates default headers (Column1, Column2, etc.)
  static List<String> generate(int count, {String prefix = 'Column'}) {
    return List.generate(count, (i) => '$prefix${i + 1}');
  }

  /// Generates headers from the first row values
  static List<String> fromRow(List<Object?> row) {
    return row.map((e) => e?.toString() ?? '').toList();
  }

  /// Normalizes headers (lowercase, replace spaces with underscores)
  static List<String> normalize(List<String> headers) {
    return headers
        .map((h) => h.toLowerCase().replaceAll(RegExp(r'\s+'), '_'))
        .toList();
  }

  /// Ensures headers are unique by appending numbers to duplicates
  static List<String> makeUnique(List<String> headers) {
    final result = <String>[];
    final counts = <String, int>{};

    for (final header in headers) {
      final count = counts[header] ?? 0;
      if (count == 0) {
        result.add(header);
      } else {
        result.add('${header}_$count');
      }
      counts[header] = count + 1;
    }

    return result;
  }
}
