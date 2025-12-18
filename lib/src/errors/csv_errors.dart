/// Base exception for CSV operations
sealed class CsvException implements Exception {
  const CsvException(this.message, {this.line, this.column});
  final String message;
  final int? line;
  final int? column;

  @override
  String toString() {
    final location = line != null
        ? ' at line $line${column != null ? ', column $column' : ''}'
        : '';
    return '$runtimeType: $message$location';
  }
}

/// Exception thrown when CSV parsing fails
final class CsvParseException extends CsvException {
  const CsvParseException(super.message, {super.line, super.column});
}

/// Exception thrown when CSV has invalid structure
final class InvalidCsvStructureException extends CsvException {
  const InvalidCsvStructureException(super.message, {super.line, super.column});
}

/// Exception thrown when settings are invalid
final class InvalidSettingsException extends CsvException {
  const InvalidSettingsException(super.message);
}

/// Exception thrown for unclosed quoted fields
final class UnclosedQuoteException extends CsvParseException {
  const UnclosedQuoteException({int? line, int? column})
      : super('Unclosed quoted field', line: line, column: column);
}

/// Exception thrown when headers are missing or invalid
final class HeaderException extends CsvException {
  const HeaderException(super.message, {super.line});
}

/// Exception thrown during export operations
final class ExportException extends CsvException {
  const ExportException(super.message);
}

/// Settings validation errors
enum SettingsError {
  eolNull('EOL cannot be null'),
  fieldDelimiterNull('Field delimiter cannot be null'),
  textDelimiterNull('Text delimiter cannot be null'),
  delimiterConflict(
      'Delimiters must be distinct and cannot be prefixes of each other'),
  emptyDelimiter('Delimiter cannot be empty');

  final String message;
  const SettingsError(this.message);

  InvalidSettingsException toException() => InvalidSettingsException(message);
}

/// Validates CSV settings
final class SettingsValidator {
  const SettingsValidator._();

  /// Validates settings and returns list of errors (empty if valid)
  static List<SettingsError> validate({
    required String fieldDelimiter,
    required String textDelimiter,
    required String textEndDelimiter,
    required String eol,
  }) {
    final errors = <SettingsError>[];

    if (fieldDelimiter.isEmpty) errors.add(SettingsError.emptyDelimiter);
    if (textDelimiter.isEmpty) errors.add(SettingsError.emptyDelimiter);
    if (eol.isEmpty) errors.add(SettingsError.emptyDelimiter);

    // Check for conflicts
    if (_hasConflict([fieldDelimiter, textDelimiter, textEndDelimiter, eol])) {
      errors.add(SettingsError.delimiterConflict);
    }

    return errors;
  }

  /// Throws if settings are invalid
  static void validateOrThrow({
    required String fieldDelimiter,
    required String textDelimiter,
    required String textEndDelimiter,
    required String eol,
  }) {
    final errors = validate(
      fieldDelimiter: fieldDelimiter,
      textDelimiter: textDelimiter,
      textEndDelimiter: textEndDelimiter,
      eol: eol,
    );

    if (errors.isNotEmpty) {
      throw errors.first.toException();
    }
  }

  static bool _hasConflict(List<String> values) {
    for (var i = 0; i < values.length; i++) {
      for (var j = i + 1; j < values.length; j++) {
        if (values[i] == values[j]) return true;
        if (values[i].startsWith(values[j]) ||
            values[j].startsWith(values[i])) {
          return true;
        }
      }
    }
    return false;
  }
}
