import '../settings/csv_settings.dart';
import '../errors/csv_errors.dart';

/// State during CSV parsing
enum _ParseState {
  fieldStart,
  unquotedField,
  quotedField,
  quotedFieldEnd,
  fieldEnd,
  rowEnd,
}

/// High-performance CSV parser with support for multi-character delimiters.
///
/// Fixes issues: #69 (iOS compatibility), #70 (parsing accuracy),
/// #33 (empty newlines), #30 (extra CR).
final class CsvParser {
  final CsvSettings settings;

  const CsvParser({this.settings = const CsvSettings()});

  /// Parses a CSV string into a list of rows
  List<List<dynamic>> parse(String csv) {
    if (csv.isEmpty) return [];

    final rows = <List<dynamic>>[];
    var currentRow = <dynamic>[];
    final field = StringBuffer();
    var state = _ParseState.fieldStart;
    var i = 0;
    var lineNumber = 1;
    var columnNumber = 1;

    while (i < csv.length) {
      final result = _processChar(
        csv: csv,
        index: i,
        state: state,
        field: field,
        currentRow: currentRow,
        rows: rows,
        lineNumber: lineNumber,
        columnNumber: columnNumber,
      );

      state = result.state;
      i = result.nextIndex;

      if (result.fieldComplete) {
        currentRow.add(_parseValue(field.toString()));
        field.clear();
      }

      if (result.rowComplete) {
        if (!settings.skipEmptyLines || _isNonEmptyRow(currentRow)) {
          rows.add(currentRow);
        }
        currentRow = <dynamic>[];
        lineNumber++;
        columnNumber = 1;
      } else {
        columnNumber++;
      }

      if (result.error != null && !settings.allowInvalid) {
        throw result.error!;
      }
    }

    // Handle final field
    if (state == _ParseState.quotedField && !settings.allowInvalid) {
      throw UnclosedQuoteException(line: lineNumber, column: columnNumber);
    }

    if (field.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(_parseValue(field.toString()));
      if (!settings.skipEmptyLines || _isNonEmptyRow(currentRow)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  /// Checks if a row has at least one non-empty value
  bool _isNonEmptyRow(List<dynamic> row) {
    if (row.isEmpty) return false;
    return row.any((v) {
      if (v == null) return false;
      final str = v.toString();
      return str.isNotEmpty;
    });
  }

  /// Parses a single row from CSV string
  List<dynamic> parseRow(String csvRow) {
    final rows = parse(csvRow);
    return rows.isEmpty ? [] : rows.first;
  }

  _ParseResult _processChar({
    required String csv,
    required int index,
    required _ParseState state,
    required StringBuffer field,
    required List<dynamic> currentRow,
    required List<List<dynamic>> rows,
    required int lineNumber,
    required int columnNumber,
  }) {
    return switch (state) {
      _ParseState.fieldStart => _handleFieldStart(csv, index, field),
      _ParseState.unquotedField => _handleUnquotedField(csv, index, field),
      _ParseState.quotedField => _handleQuotedField(csv, index, field),
      _ParseState.quotedFieldEnd =>
        _handleQuotedFieldEnd(csv, index, field, lineNumber, columnNumber),
      _ParseState.fieldEnd => _handleFieldStart(csv, index, field),
      _ParseState.rowEnd => _handleFieldStart(csv, index, field),
    };
  }

  _ParseResult _handleFieldStart(String csv, int index, StringBuffer field) {
    // Check for text delimiter (start of quoted field)
    if (_matchesAt(csv, index, settings.textDelimiter)) {
      return _ParseResult(
        state: _ParseState.quotedField,
        nextIndex: index + settings.textDelimiter.length,
      );
    }

    // Check for field delimiter (empty field)
    if (_matchesAt(csv, index, settings.fieldDelimiter)) {
      return _ParseResult(
        state: _ParseState.fieldStart,
        nextIndex: index + settings.fieldDelimiter.length,
        fieldComplete: true,
      );
    }

    // Check for EOL (empty row or empty final field)
    if (_matchesAt(csv, index, settings.eol)) {
      return _ParseResult(
        state: _ParseState.fieldStart,
        nextIndex: index + settings.eol.length,
        fieldComplete: true,
        rowComplete: true,
      );
    }

    // Handle standalone \r or \n when eol is \r\n
    if (settings.eol == '\r\n') {
      if (csv[index] == '\n') {
        return _ParseResult(
          state: _ParseState.fieldStart,
          nextIndex: index + 1,
          fieldComplete: true,
          rowComplete: true,
        );
      }
    }

    // Start of unquoted field
    field.write(csv[index]);
    return _ParseResult(
      state: _ParseState.unquotedField,
      nextIndex: index + 1,
    );
  }

  _ParseResult _handleUnquotedField(String csv, int index, StringBuffer field) {
    // Check for field delimiter
    if (_matchesAt(csv, index, settings.fieldDelimiter)) {
      return _ParseResult(
        state: _ParseState.fieldStart,
        nextIndex: index + settings.fieldDelimiter.length,
        fieldComplete: true,
      );
    }

    // Check for EOL
    if (_matchesAt(csv, index, settings.eol)) {
      return _ParseResult(
        state: _ParseState.fieldStart,
        nextIndex: index + settings.eol.length,
        fieldComplete: true,
        rowComplete: true,
      );
    }

    // Handle standalone \r or \n when eol is \r\n
    if (settings.eol == '\r\n') {
      if (csv[index] == '\n') {
        return _ParseResult(
          state: _ParseState.fieldStart,
          nextIndex: index + 1,
          fieldComplete: true,
          rowComplete: true,
        );
      }
    }

    // Continue building field
    field.write(csv[index]);
    return _ParseResult(
      state: _ParseState.unquotedField,
      nextIndex: index + 1,
    );
  }

  _ParseResult _handleQuotedField(String csv, int index, StringBuffer field) {
    // Check for text end delimiter
    if (_matchesAt(csv, index, settings.textEndDelimiter)) {
      // Check if it's an escaped quote (doubled)
      final afterDelimiter = index + settings.textEndDelimiter.length;
      if (afterDelimiter < csv.length &&
          _matchesAt(csv, afterDelimiter, settings.textDelimiter)) {
        // Escaped quote - add single quote to field
        field.write(settings.textDelimiter);
        return _ParseResult(
          state: _ParseState.quotedField,
          nextIndex: afterDelimiter + settings.textDelimiter.length,
        );
      }

      // End of quoted field
      return _ParseResult(
        state: _ParseState.quotedFieldEnd,
        nextIndex: afterDelimiter,
      );
    }

    // Any other character is part of the field
    field.write(csv[index]);
    return _ParseResult(
      state: _ParseState.quotedField,
      nextIndex: index + 1,
    );
  }

  _ParseResult _handleQuotedFieldEnd(
    String csv,
    int index,
    StringBuffer field,
    int lineNumber,
    int columnNumber,
  ) {
    // Check for field delimiter
    if (_matchesAt(csv, index, settings.fieldDelimiter)) {
      return _ParseResult(
        state: _ParseState.fieldStart,
        nextIndex: index + settings.fieldDelimiter.length,
        fieldComplete: true,
      );
    }

    // Check for EOL
    if (_matchesAt(csv, index, settings.eol)) {
      return _ParseResult(
        state: _ParseState.fieldStart,
        nextIndex: index + settings.eol.length,
        fieldComplete: true,
        rowComplete: true,
      );
    }

    // Handle standalone \r or \n when eol is \r\n
    if (settings.eol == '\r\n') {
      if (csv[index] == '\n') {
        return _ParseResult(
          state: _ParseState.fieldStart,
          nextIndex: index + 1,
          fieldComplete: true,
          rowComplete: true,
        );
      }
    }

    // Invalid character after closing quote
    if (!settings.allowInvalid) {
      return _ParseResult(
        state: _ParseState.quotedFieldEnd,
        nextIndex: index + 1,
        error: CsvParseException(
          'Unexpected character after closing quote: "${csv[index]}"',
          line: lineNumber,
          column: columnNumber,
        ),
      );
    }

    // In lenient mode, treat as part of next field
    field.write(csv[index]);
    return _ParseResult(
      state: _ParseState.unquotedField,
      nextIndex: index + 1,
    );
  }

  bool _matchesAt(String text, int index, String pattern) {
    if (index + pattern.length > text.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (text[index + i] != pattern[i]) return false;
    }
    return true;
  }

  dynamic _parseValue(String value) {
    final trimmed = settings.trimFields ? value.trim() : value;

    if (!settings.parseNumbers) return trimmed;

    // Try parsing as int
    final intValue = int.tryParse(trimmed);
    if (intValue != null) return intValue;

    // Try parsing as double
    var doubleString = trimmed;
    if (settings.decimalSeparator != '.') {
      doubleString = trimmed.replaceAll(settings.decimalSeparator, '.');
    }
    final doubleValue = double.tryParse(doubleString);
    if (doubleValue != null) return doubleValue;

    return trimmed;
  }
}

/// Result of processing a single character
final class _ParseResult {
  final _ParseState state;
  final int nextIndex;
  final bool fieldComplete;
  final bool rowComplete;
  final CsvException? error;

  const _ParseResult({
    required this.state,
    required this.nextIndex,
    this.fieldComplete = false,
    this.rowComplete = false,
    this.error,
  });
}
