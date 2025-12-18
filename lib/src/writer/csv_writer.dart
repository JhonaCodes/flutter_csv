import '../settings/csv_settings.dart';
import '../sanitizer/csv_sanitizer.dart';

/// Converts List<List> data structures into CSV strings.
final class CsvWriter {
  CsvWriter({this.settings = const CsvSettings()})
      : _sanitizer = CsvSanitizer(
          settings: settings,
          mode: settings.quoteAllFields
              ? SanitizeMode.quoteAll
              : SanitizeMode.minimal,
        );
  final CsvSettings settings;
  final CsvSanitizer _sanitizer;

  /// Converts a list of rows to a CSV string
  String write(List<List<Object?>> rows) {
    if (rows.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < rows.length; i++) {
      buffer.write(_writeRow(rows[i]));
      if (i < rows.length - 1) {
        buffer.write(settings.eol);
      }
    }
    return buffer.toString();
  }

  /// Converts a list of rows to a CSV string with trailing EOL
  String writeWithTrailingEol(List<List<Object?>> rows) {
    if (rows.isEmpty) return '';
    return '${write(rows)}${settings.eol}';
  }

  /// Converts a single row to a CSV string
  String writeRow(List<Object?> row) => _writeRow(row);

  String _writeRow(List<Object?> row) {
    return row.map(_sanitizer.sanitize).join(settings.fieldDelimiter);
  }

  /// Creates a new writer with modified settings
  CsvWriter copyWith({CsvSettings? settings}) {
    return CsvWriter(settings: settings ?? this.settings);
  }
}
