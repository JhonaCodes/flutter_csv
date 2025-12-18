/// Configuration settings for CSV parsing and generation.
///
/// This class provides flexible configuration for CSV operations,
/// addressing common issues like EOL handling (fixes issue #74, #4, #30).
final class CsvSettings {
  const CsvSettings({
    this.fieldDelimiter = ',',
    this.textDelimiter = '"',
    String? textEndDelimiter,
    this.eol = '\n',
    this.parseNumbers = false,
    this.quoteAllFields = false,
    this.nullValue,
    this.decimalSeparator = '.',
    this.trimFields = false,
    this.skipEmptyLines = true,
    this.allowInvalid = true,
  }) : textEndDelimiter = textEndDelimiter ?? textDelimiter;

  /// Field separator (default: ',')
  final String fieldDelimiter;

  /// Text quote character (default: '"')
  final String textDelimiter;

  /// End text quote character (can differ from textDelimiter for asymmetric quotes)
  final String textEndDelimiter;

  /// End of line character (default: '\n' - fixes issue #74)
  final String eol;

  /// Whether to parse numeric strings into int/double
  final bool parseNumbers;

  /// Whether to quote all fields regardless of content
  final bool quoteAllFields;

  /// Value to use for null fields
  final String? nullValue;

  /// Decimal separator for number parsing (fixes issue #60)
  final String decimalSeparator;

  /// Whether to trim whitespace from fields
  final bool trimFields;

  /// Whether to skip empty lines (fixes issue #33)
  final bool skipEmptyLines;

  /// Whether to allow invalid CSV (lenient parsing)
  final bool allowInvalid;

  /// RFC 4180 compliant settings
  static const rfc4180 = CsvSettings(
    fieldDelimiter: ',',
    textDelimiter: '"',
    eol: '\r\n',
    parseNumbers: false,
    quoteAllFields: false,
    skipEmptyLines: false,
  );

  /// Excel-friendly settings
  static const excel = CsvSettings(
    fieldDelimiter: ',',
    textDelimiter: '"',
    eol: '\r\n',
    parseNumbers: true,
    quoteAllFields: true,
    skipEmptyLines: true,
  );

  /// European CSV settings (semicolon separator, comma decimal)
  static const european = CsvSettings(
    fieldDelimiter: ';',
    textDelimiter: '"',
    eol: '\n',
    parseNumbers: true,
    decimalSeparator: ',',
    skipEmptyLines: true,
  );

  /// Tab-separated values settings
  static const tsv = CsvSettings(
    fieldDelimiter: '\t',
    textDelimiter: '"',
    eol: '\n',
    parseNumbers: false,
    skipEmptyLines: true,
  );

  /// Creates a copy with modified fields
  CsvSettings copyWith({
    String? fieldDelimiter,
    String? textDelimiter,
    String? textEndDelimiter,
    String? eol,
    bool? parseNumbers,
    bool? quoteAllFields,
    String? nullValue,
    String? decimalSeparator,
    bool? trimFields,
    bool? skipEmptyLines,
    bool? allowInvalid,
  }) {
    return CsvSettings(
      fieldDelimiter: fieldDelimiter ?? this.fieldDelimiter,
      textDelimiter: textDelimiter ?? this.textDelimiter,
      textEndDelimiter: textEndDelimiter ?? this.textEndDelimiter,
      eol: eol ?? this.eol,
      parseNumbers: parseNumbers ?? this.parseNumbers,
      quoteAllFields: quoteAllFields ?? this.quoteAllFields,
      nullValue: nullValue ?? this.nullValue,
      decimalSeparator: decimalSeparator ?? this.decimalSeparator,
      trimFields: trimFields ?? this.trimFields,
      skipEmptyLines: skipEmptyLines ?? this.skipEmptyLines,
      allowInvalid: allowInvalid ?? this.allowInvalid,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CsvSettings &&
          runtimeType == other.runtimeType &&
          fieldDelimiter == other.fieldDelimiter &&
          textDelimiter == other.textDelimiter &&
          textEndDelimiter == other.textEndDelimiter &&
          eol == other.eol &&
          parseNumbers == other.parseNumbers &&
          quoteAllFields == other.quoteAllFields &&
          nullValue == other.nullValue &&
          decimalSeparator == other.decimalSeparator &&
          trimFields == other.trimFields &&
          skipEmptyLines == other.skipEmptyLines &&
          allowInvalid == other.allowInvalid;

  @override
  int get hashCode => Object.hash(
        fieldDelimiter,
        textDelimiter,
        textEndDelimiter,
        eol,
        parseNumbers,
        quoteAllFields,
        nullValue,
        decimalSeparator,
        trimFields,
        skipEmptyLines,
        allowInvalid,
      );
}
