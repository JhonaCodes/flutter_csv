# flutter_csv

A CSV library for Dart/Flutter with builder pattern, import/export capabilities, header detection, JSON and MessagePack conversion.

[![Pub Version](https://img.shields.io/pub/v/flutter_csv)](https://pub.dev/packages/flutter_csv)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

## Features

- **Builder Pattern**: Fluent API for creating CSV content
- **Import & Export**: Parse and write CSV files with ease
- **Auto-Detection**: Automatically detect delimiters, EOL, and headers
- **Multiple Formats**: Support for CSV, TSV, European CSV, RFC 4180, Excel
- **JSON Conversion**: Seamless CSV ↔ JSON conversion
- **MessagePack**: Binary serialization with CSV ↔ MsgPack conversion
- **MCP Integration**: Full Model Context Protocol support with Tools, Resources, and Prompts conversion
- **File I/O**: Built-in file save/load operations
- **Large Files**: Chunked processing and streaming for large files
- **Web Compatible**: Browser-friendly exports with BOM support

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_csv: ^1.0.2
```

## Quick Start

### Parsing CSV

```dart
import 'package:flutter_csv/flutter_csv.dart';

// Simple parse
final data = FlutterCsv.parse('Name,Age\nJohn,30\nJane,25');

// With auto-detection of delimiters
final data = FlutterCsv.parseAuto(csvString);

// As document with headers
final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);
print(doc.headers);     // ['Name', 'Age']
print(doc.rowCount);    // 2
```

### Building CSV

```dart
// Using builder pattern
final builder = FlutterCsv.builder()
  ..columns(['Name', 'Age', 'City'])
  ..row(['John', 30, 'NYC'])
  ..row(['Jane', 25, 'LA'])
  ..row(['Bob', 35, 'Chicago']);

final doc = builder.build();
print(doc.toCsv());
// Output:
// Name,Age,City
// John,30,NYC
// Jane,25,LA
// Bob,35,Chicago

// Quick export without building
final csvString = builder.export();
```

### Writing CSV

```dart
// Write rows directly
final csv = FlutterCsv.write([
  ['Name', 'Age'],
  ['John', 30],
  ['Jane', 25],
]);

// With custom settings
final csv = FlutterCsv.write(
  rows,
  settings: CsvSettings.european,  // Uses semicolon delimiter
);
```

### Format Presets

```dart
// RFC 4180 compliant (CRLF line endings)
final builder = FlutterCsv.rfc4180Builder();

// Excel-friendly (quoted fields, BOM)
final builder = FlutterCsv.excelBuilder();

// European style (semicolon separator, comma decimal)
final builder = FlutterCsv.europeanBuilder();

// Tab-separated values
final builder = FlutterCsv.tsvBuilder();
```

### JSON Conversion

```dart
// CSV to JSON
final json = FlutterCsv.toJson(csvString);
// [{"Name":"John","Age":"30"},{"Name":"Jane","Age":"25"}]

// JSON to CSV
final csv = FlutterCsv.fromJson(jsonString);

// CSV to List of Maps
final maps = FlutterCsv.toMaps(csvString);
// [{Name: John, Age: 30}, {Name: Jane, Age: 25}]

// Maps to CSV
final csv = FlutterCsv.fromMaps([
  {'name': 'John', 'age': 30},
  {'name': 'Jane', 'age': 25},
]);
```

### MessagePack Conversion

**(Note: MessagePack is a binary serialization format and is distinct from Model Context Protocol (MCP).)**

// CSV to MessagePack
final bytes = FlutterCsv.toMsgPack(csvString);

// MessagePack to CSV
final csv = FlutterCsv.fromMsgPack(bytes);

// MessagePack to Document
final doc = FlutterCsv.parseMsgPack(bytes);

### Model Context Protocol (MCP) Integration

This library provides utilities to integrate CSV data with the Model Context Protocol (MCP), a JSON-based protocol often used for exchanging data as Resources, Tools, or Prompts, especially in AI model configurations.

#### Basic MCP TextResource Conversion

The `McpConverter` allows for simple conversion between CSV strings and MCP TextResource JSON objects, where the CSV content is embedded as a `text` field within a JSON structure.

```dart
// CSV to MCP TextResource JSON string
final mcpJson = FlutterCsv.toMcp(
  'Name,Age\nJohn,30',
  uri: 'http://example.com/data.csv',
  name: 'UserData',
);
print(mcpJson);
// Output:
// {
//   "uri": "http://example.com/data.csv",
//   "name": "UserData",
//   "mimeType": "text/csv",
//   "text": "Name,Age\\nJohn,30"
// }

// CSV to MCP TextResource Map (without JSON encoding)
final mcpMap = FlutterCsv.toMcpMap(
  'Name,Age\nJohn,30',
  uri: 'http://example.com/data.csv',
  name: 'UserData',
);
print(mcpMap);
// Output: Map<String, dynamic>

// MCP TextResource JSON to CSV
final csv = FlutterCsv.fromMcp(mcpJson);
print(csv);
// Output:
// Name,Age
// John,30
```

#### Advanced MCP Schema Conversion

The `McpSchemaConverter` enables more structured conversions, allowing you to transform CSV documents into MCP definitions for Tools (with JSON Schema arguments), Resources, and Prompts.

**1. CSV to MCP Tools**

Converts a CSV string into a list of MCP Tool definitions. The CSV must have headers: `tool_name`, `tool_description`, `arg_name`, `arg_type` (string, number, boolean, object, array), and `required` (true/false).

```dart
final toolsCsv = """
tool_name,tool_description,arg_name,arg_type,required
get_weather,Fetches current weather for a location,location,string,true
get_weather,Fetches current weather for a location,unit,string,false
send_email,Sends an email to a recipient,to,string,true
send_email,Sends an email to a recipient,subject,string,false
send_email,Sends an email to a recipient,body,string,true
""";

final mcpTools = FlutterCsv.convertMcpTools(toolsCsv);
print(mcpTools);
// Output:
// [
//   {
//     name: get_weather,
//     description: Fetches current weather for a location,
//     inputSchema: {
//       type: object,
//       properties: {
//         location: {type: string},
//         unit: {type: string}
//       },
//       required: [location]
//     }
//   },
//   {
//     name: send_email,
//     description: Sends an email to a recipient,
//     inputSchema: {
//       type: object,
//       properties: {
//         to: {type: string},
//       subject: {type: string},
//         body: {type: string}
//       },
//       required: [to, body]
//     }
//   }
// ]
```

**2. CSV to MCP Resources**

Converts a CSV string into a list of MCP Resource definitions. The CSV must have headers: `uri`, `type` (optional, defaults to `text/plain`), `description` (optional), and `name` (optional).

```dart
final resourcesCsv = """
uri,type,description,name
http://example.com/doc1,text/plain,First document,Document1
http://example.com/image1,image/jpeg,A sample image,Image1
""";

final mcpResources = FlutterCsv.convertMcpResources(resourcesCsv);
print(mcpResources);
// Output:
// [
//   {
//     uri: http://example.com/doc1,
//     mimeType: text/plain,
//     description: First document,
//     name: Document1
//   },
//   {
//     uri: http://example.com/image1,
//     mimeType: image/jpeg,
//     description: A sample image,
//     name: Image1
//   }
// ]
```

**3. CSV to MCP Prompts**

Converts a CSV string into a list of MCP Prompt definitions. The CSV must have headers: `prompt_name`, `role` (user, assistant, system), and `content`.

```dart
final promptsCsv = """
prompt_name,role,content
greeting_prompt,user,Hello, how are you?
greeting_prompt,assistant,I am fine, thank you. How can I help?
summarize_text,user,Please summarize the following text:
""";

final mcpPrompts = FlutterCsv.convertMcpPrompts(promptsCsv);
print(mcpPrompts);
// Output:
// [
//   {
//     name: greeting_prompt,
//     messages: [
//       {role: user, content: {type: text, text: Hello, how are you?}},
//       {role: assistant, content: {type: text, text: I am fine, thank you. How can I help?}}
//     ]
//   },
//   {
//     name: summarize_text,
//     messages: [
//       {role: user, content: {type: text, text: Please summarize the following text:}}
//     ]
//   }
// ]
```

### File Operations

```dart
// Save to file
final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);
await doc.saveToFile('data.csv');

// Save with specific format
await doc.saveToFile('data.csv', format: CsvFileFormat.csv);
await doc.saveToFile('data.tsv', format: CsvFileFormat.tsv);
await doc.saveToFile('data.json', format: CsvFileFormat.json);
await doc.saveToFile('data.msgpack', format: CsvFileFormat.msgpack);

// Load from file
final doc = await FlutterCsv.loadFromFile('data.csv', firstRowIsHeader: true);

// Load MessagePack file
final doc = await FlutterCsv.loadMsgPackFile('data.msgpack');

// Save rows directly
await FlutterCsv.saveRowsToFile(
  rows,
  'output.csv',
  headers: ['Name', 'Age'],
);

// Streaming for large files
await FlutterCsv.saveStreaming(doc, 'large.csv', chunkSize: 1000);

// Read line by line
await for (final row in FlutterCsv.readFileLines('large.csv')) {
  print(row);
}
```

### Document Operations

```dart
final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);

// Access data
print(doc.headers);                    // Column headers
print(doc.rowCount);                   // Number of rows
print(doc.getRow(0));                  // First row
print(doc.getCell(0, 1));              // Cell at row 0, column 1
print(doc.getCellByHeader(0, 'Name')); // Cell by header name
print(doc.getColumn(0));               // All values in column 0
print(doc.getColumnByHeader('Age'));   // All values in 'Age' column

// Export
print(doc.toCsv());                    // To CSV string
print(doc.toJson());                   // To JSON string
print(doc.toMaps());                   // To List<Map>

// Header manipulation
final withHeaders = doc.promoteFirstRowToHeaders();
final withoutHeaders = doc.demoteHeadersToFirstRow();
```

### Header Detection

```dart
// Auto-detect if first row is a header
final doc = FlutterCsv.parseWithAutoHeaders(csvString);

// Manual detection
final detection = FlutterCsv.detectHeaders(data);
print(detection.isHeader);     // true/false
print(detection.confidence);   // 0.0 to 1.0
print(detection.headers);      // Detected headers

// Header utilities
final headers = FlutterCsv.generateHeaders(5);           // ['Column1', ..., 'Column5']
final normalized = FlutterCsv.normalizeHeaders(headers); // ['column_1', ...]
final unique = FlutterCsv.uniqueHeaders(['a', 'a']);     // ['a', 'a_1']
```

### Custom Settings

```dart
final settings = CsvSettings(
  fieldDelimiter: ',',       // Field separator
  textDelimiter: '"',        // Quote character
  eol: '\n',                 // End of line
  parseNumbers: true,        // Parse numeric strings
  quoteAllFields: false,     // Quote all fields
  nullValue: '',             // Value for null
  decimalSeparator: '.',     // Decimal separator
  trimFields: false,         // Trim whitespace
  skipEmptyLines: true,      // Skip empty lines
  allowInvalid: true,        // Lenient parsing
);

// Or use presets
CsvSettings.rfc4180    // RFC 4180 compliant
CsvSettings.excel      // Excel-friendly
CsvSettings.european   // European style
CsvSettings.tsv        // Tab-separated
```

### Export Formats

```dart
final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);

// Export with format options
final result = doc.export(format: CsvExportFormat.excel);
print(result.content);     // CSV string
print(result.bytes);       // Uint8List
print(result.extension);   // 'csv'
print(result.mimeType);    // 'application/vnd.ms-excel'

// Web-compatible export (with BOM for Safari)
final result = doc.exportForWeb();

// Chunked export for large files
for (final chunk in doc.exportInChunks(chunkSize: 1000)) {
  // Process chunk
}
```

### Sanitization

```dart
// Sanitize values for CSV
final safe = FlutterCsv.sanitize('hello, world');  // "hello, world"
final safe = FlutterCsv.sanitize('say "hi"');      // "say ""hi"""

// Different modes
FlutterCsv.sanitize(value, mode: SanitizeMode.minimal);     // Quote only when needed
FlutterCsv.sanitize(value, mode: SanitizeMode.quoteStrings); // Quote all strings
FlutterCsv.sanitize(value, mode: SanitizeMode.quoteAll);    // Quote everything
FlutterCsv.sanitize(value, mode: SanitizeMode.escape);      // Escape special chars
```

## Error Handling

```dart
try {
  final doc = FlutterCsv.parseDocument(
    csv,
    settings: CsvSettings(allowInvalid: false),
  );
} on UnclosedQuoteException catch (e) {
  print('Unclosed quote at line ${e.line}');
} on CsvParseException catch (e) {
  print('Parse error: ${e.message}');
}
```

## Key Capabilities

### CSV Handling

- **Cross-platform EOL Support**: Handles `\n`, `\r\n`, and `\r` line endings seamlessly across all platforms
- **Smart Header Detection**: Automatically identifies header rows using pattern analysis and type inference
- **Empty Line Management**: Configurable behavior for empty lines - skip or preserve as needed
- **International Number Formats**: Full support for European decimal separators (comma) and custom formats

### Data Integrity

- **Proper Quote Escaping**: RFC 4180 compliant escaping with doubled quotes inside quoted fields
- **Special Character Handling**: Correctly handles commas, newlines, and quotes within field values
- **Type Preservation**: Optional number parsing while maintaining string integrity when needed

### Performance & Compatibility

- **Large File Support**: Stream processing and chunked exports for files of any size
- **Browser Compatibility**: UTF-8 BOM support for proper encoding in Safari and other browsers
- **Memory Efficient**: Lazy evaluation and streaming for minimal memory footprint

### Flexibility

- **Multiple Format Presets**: RFC 4180, Excel, European CSV, TSV out of the box
- **Customizable Settings**: Full control over delimiters, quotes, EOL, and parsing behavior
- **Extensible Architecture**: Clean separation of concerns for easy customization

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Created by [JhonaCodes](https://github.com/JhonaCodes)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
