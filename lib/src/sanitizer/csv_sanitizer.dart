import '../settings/csv_settings.dart';

/// Sanitization mode for CSV values
enum SanitizeMode {
  /// Only quote when necessary (contains delimiters, quotes, or newlines)
  minimal,

  /// Quote all string fields
  quoteStrings,

  /// Quote all fields regardless of type
  quoteAll,

  /// No quoting, escape special characters
  escape,
}

/// Elegant sanitizer for CSV values using modern Dart patterns.
///
/// Handles escaping (fixes issue #59) and proper quoting (fixes issue #6).
final class CsvSanitizer {
  const CsvSanitizer({
    this.settings = const CsvSettings(),
    this.mode = SanitizeMode.minimal,
  });

  final CsvSettings settings;
  final SanitizeMode mode;

  /// Sanitizes a single value for CSV output
  String sanitize(Object? value) {
    final stringValue = _convertToString(value);
    return _applySanitization(stringValue, value);
  }

  /// Sanitizes a row of values
  List<String> sanitizeRow(List<Object?> row) {
    return row.map(sanitize).toList();
  }

  /// Sanitizes entire data set
  List<List<String>> sanitizeAll(List<List<Object?>> data) {
    return data.map(sanitizeRow).toList();
  }

  String _convertToString(Object? value) => switch (value) {
        null => settings.nullValue ?? '',
        final String s => s,
        final int i => i.toString(),
        final double d => _formatDouble(d),
        final bool b => b.toString(),
        final DateTime dt => dt.toIso8601String(),
        final Iterable it => it.map(_convertToString).join(','),
        final Map m => m.entries
            .map((e) =>
                '${_convertToString(e.key)}:${_convertToString(e.value)}')
            .join(','),
        _ => value.toString(),
      };

  String _formatDouble(double value) {
    final str = value.toString();
    if (settings.decimalSeparator != '.') {
      return str.replaceAll('.', settings.decimalSeparator);
    }
    return str;
  }

  String _applySanitization(String value, Object? originalValue) =>
      switch (mode) {
        SanitizeMode.quoteAll => _quote(value),
        SanitizeMode.quoteStrings when originalValue is String => _quote(value),
        SanitizeMode.quoteStrings => _quoteIfNeeded(value),
        SanitizeMode.escape => _escape(value),
        SanitizeMode.minimal => _quoteIfNeeded(value),
      };

  bool _needsQuoting(String value) {
    if (value.isEmpty) return false;

    // Check for special characters using codeUnits for performance
    final fieldDelimiterUnits = settings.fieldDelimiter.codeUnits;
    final textDelimiterUnits = settings.textDelimiter.codeUnits;
    final eolUnits = settings.eol.codeUnits;

    return _containsSequence(value, fieldDelimiterUnits) ||
        _containsSequence(value, textDelimiterUnits) ||
        _containsSequence(value, eolUnits) ||
        value.contains('\n') ||
        value.contains('\r');
  }

  bool _containsSequence(String text, List<int> sequence) {
    if (sequence.isEmpty) return false;
    if (sequence.length == 1) {
      return text.codeUnits.contains(sequence.first);
    }

    final textUnits = text.codeUnits;
    outer:
    for (var i = 0; i <= textUnits.length - sequence.length; i++) {
      for (var j = 0; j < sequence.length; j++) {
        if (textUnits[i + j] != sequence[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  String _quote(String value) {
    final escaped = _escapeQuotes(value);
    return '${settings.textDelimiter}$escaped${settings.textEndDelimiter}';
  }

  String _quoteIfNeeded(String value) {
    if (!_needsQuoting(value)) return value;
    return _quote(value);
  }

  String _escapeQuotes(String value) {
    // Double the text delimiter to escape it (RFC 4180 rule 7)
    return value.replaceAll(
      settings.textDelimiter,
      '${settings.textDelimiter}${settings.textDelimiter}',
    );
  }

  String _escape(String value) {
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      buffer.write(_escapeChar(char));
    }
    return buffer.toString();
  }

  String _escapeChar(String char) => switch (char) {
        _ when char == settings.fieldDelimiter => '\\$char',
        _ when char == settings.textDelimiter => '\\$char',
        '\n' => '\\n',
        '\r' => '\\r',
        '\t' => '\\t',
        '\\' => '\\\\',
        _ => char,
      };

  /// Creates a copy with different settings
  CsvSanitizer copyWith({
    CsvSettings? settings,
    SanitizeMode? mode,
  }) {
    return CsvSanitizer(
      settings: settings ?? this.settings,
      mode: mode ?? this.mode,
    );
  }
}

/// Extension for convenient sanitization
extension SanitizeExtension on Object? {
  String sanitizeForCsv([CsvSettings settings = const CsvSettings()]) {
    return CsvSanitizer(settings: settings).sanitize(this);
  }
}
