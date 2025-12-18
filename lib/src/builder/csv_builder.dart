import '../settings/csv_settings.dart';
import 'csv_document.dart';

/// Fluent builder for creating CSV content.
///
/// Example usage:
/// ```dart
/// final csv = CsvBuilder()
///   ..columns(['Name', 'Age', 'City'])
///   ..row(['John', 30, 'NYC'])
///   ..row(['Jane', 25, 'LA'])
///   ..build();
///
/// csv.export(); // Get CSV string
/// ```
final class CsvBuilder {
  CsvSettings _settings = const CsvSettings();
  final List<String> _columns = [];
  final List<List<Object?>> _rows = [];
  bool _hasHeaders = false;

  /// Sets the CSV settings
  CsvBuilder settings(CsvSettings settings) {
    _settings = settings;
    return this;
  }

  /// Sets the field delimiter
  CsvBuilder fieldDelimiter(String delimiter) {
    _settings = _settings.copyWith(fieldDelimiter: delimiter);
    return this;
  }

  /// Sets the text delimiter (quote character)
  CsvBuilder textDelimiter(String delimiter) {
    _settings = _settings.copyWith(
      textDelimiter: delimiter,
      textEndDelimiter: delimiter,
    );
    return this;
  }

  /// Sets the end of line character
  CsvBuilder eol(String eol) {
    _settings = _settings.copyWith(eol: eol);
    return this;
  }

  /// Enables/disables number parsing
  CsvBuilder parseNumbers(bool parse) {
    _settings = _settings.copyWith(parseNumbers: parse);
    return this;
  }

  /// Enables/disables quoting all fields
  CsvBuilder quoteAllFields(bool quote) {
    _settings = _settings.copyWith(quoteAllFields: quote);
    return this;
  }

  /// Sets the value for null fields
  CsvBuilder nullValue(String? value) {
    _settings = _settings.copyWith(nullValue: value);
    return this;
  }

  /// Sets the decimal separator
  CsvBuilder decimalSeparator(String separator) {
    _settings = _settings.copyWith(decimalSeparator: separator);
    return this;
  }

  /// Enables/disables field trimming
  CsvBuilder trimFields(bool trim) {
    _settings = _settings.copyWith(trimFields: trim);
    return this;
  }

  /// Enables/disables skipping empty lines
  CsvBuilder skipEmptyLines(bool skip) {
    _settings = _settings.copyWith(skipEmptyLines: skip);
    return this;
  }

  /// Uses RFC 4180 settings
  CsvBuilder rfc4180() {
    _settings = CsvSettings.rfc4180;
    return this;
  }

  /// Uses Excel-friendly settings
  CsvBuilder excel() {
    _settings = CsvSettings.excel;
    return this;
  }

  /// Uses European CSV settings
  CsvBuilder european() {
    _settings = CsvSettings.european;
    return this;
  }

  /// Uses TSV settings
  CsvBuilder tsv() {
    _settings = CsvSettings.tsv;
    return this;
  }

  /// Sets the column headers
  CsvBuilder columns(List<String> headers) {
    _columns.clear();
    _columns.addAll(headers);
    _hasHeaders = true;
    return this;
  }

  /// Adds a single row of data
  CsvBuilder row(List<Object?> data) {
    _rows.add(data);
    return this;
  }

  /// Adds multiple rows of data
  CsvBuilder rows(List<List<Object?>> data) {
    _rows.addAll(data);
    return this;
  }

  /// Adds data from a map (keys become columns if not set)
  CsvBuilder fromMap(Map<String, Object?> map) {
    if (!_hasHeaders) {
      _columns.addAll(map.keys);
      _hasHeaders = true;
    }
    _rows.add(_columns.map((col) => map[col]).toList());
    return this;
  }

  /// Adds data from multiple maps
  CsvBuilder fromMaps(List<Map<String, Object?>> maps) {
    if (maps.isEmpty) return this;

    if (!_hasHeaders) {
      // Collect all unique keys as headers
      final allKeys = <String>{};
      for (final map in maps) {
        allKeys.addAll(map.keys);
      }
      _columns.addAll(allKeys);
      _hasHeaders = true;
    }

    for (final map in maps) {
      _rows.add(_columns.map((col) => map[col]).toList());
    }
    return this;
  }

  /// Adds a column with values
  CsvBuilder addColumn(String header, List<Object?> values) {
    _columns.add(header);
    _hasHeaders = true;

    // Ensure all rows have enough columns
    for (var i = 0; i < _rows.length; i++) {
      _rows[i].add(i < values.length ? values[i] : null);
    }

    // Add remaining values as new rows if needed
    for (var i = _rows.length; i < values.length; i++) {
      final newRow = List<Object?>.filled(_columns.length - 1, null);
      newRow.add(values[i]);
      _rows.add(newRow);
    }

    return this;
  }

  /// Clears all data
  CsvBuilder clear() {
    _columns.clear();
    _rows.clear();
    _hasHeaders = false;
    return this;
  }

  /// Builds the CSV document
  CsvDocument build() {
    return CsvDocument(
      settings: _settings,
      headers: _hasHeaders ? List.unmodifiable(_columns) : null,
      data: List.unmodifiable(_rows.map((r) => List.unmodifiable(r)).toList()),
    );
  }

  /// Quickly exports to CSV string
  String export() => build().toCsv();

  /// Gets current row count
  int get rowCount => _rows.length;

  /// Gets current column count
  int get columnCount =>
      _hasHeaders ? _columns.length : (_rows.isEmpty ? 0 : _rows.first.length);

  /// Whether headers are set
  bool get hasHeaders => _hasHeaders;
}

/// Extension for creating CsvBuilder from existing data
extension CsvBuilderExtensions on List<List<Object?>> {
  /// Creates a CsvBuilder from this list
  CsvBuilder toCsvBuilder({bool firstRowIsHeader = false}) {
    final builder = CsvBuilder();
    if (isEmpty) return builder;

    if (firstRowIsHeader && isNotEmpty) {
      builder.columns(first.map((e) => e?.toString() ?? '').toList());
      builder.rows(skip(1).toList());
    } else {
      builder.rows(this);
    }

    return builder;
  }
}
