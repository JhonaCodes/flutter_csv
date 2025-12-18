import 'dart:developer';

import 'package:flutter_csv/flutter_csv.dart';

void main() async {
  log('=== FlutterCSV Example ===\n');

  // 1. Parsing CSV
  log('--- 1. Parsing CSV ---');
  const simpleCsv = 'Name,Age,City\nJohn,30,NYC\nJane,25,LA';
  final data = FlutterCsv.parse(simpleCsv);
  log('Parsed ${data.length} rows (excluding header check):');
  for (var row in data) {
    log('$row');
  }

  // 2. Building CSV
  log('\n--- 2. Building CSV ---');
  final builder = FlutterCsv.builder()
    ..columns(['Product', 'Price', 'Stock'])
    ..row(['Laptop', 999.99, 50])
    ..row(['Phone', 599.99, 100]);

  final builtDoc = builder.build();
  log('Generated CSV:');
  log(builtDoc.toCsv());

  // 3. JSON Conversion
  log('\n--- 3. JSON Conversion ---');
  final jsonString = FlutterCsv.toJson(simpleCsv);
  log('CSV to JSON:');
  log(jsonString);

  final backToCsv = FlutterCsv.fromJson(jsonString);
  log('\nJSON back to CSV:');
  log(backToCsv);

  // 4. Working with Documents and Headers
  log('\n--- 4. Document & Headers ---');
  final doc = FlutterCsv.parseDocument(simpleCsv, firstRowIsHeader: true);
  log('Headers: ${doc.headers}');

  // Access by column name using helper
  log('Row 1 "Name" (via getCellByHeader): ${doc.getCellByHeader(0, 'Name')}');

  // Or convert to maps
  if (doc.hasHeaders) {
    final maps = doc.toMaps();
    log('Row 1 "Name" (via toMaps): ${maps.first['Name']}');
  }

  // 5. MessagePack Conversion (Optional feature)
  log('\n--- 5. MessagePack Conversion ---');
  try {
    final msgPack = FlutterCsv.toMsgPack(simpleCsv);
    log('Converted to MessagePack (${msgPack.length} bytes)');

    final fromMsgPack = FlutterCsv.fromMsgPack(msgPack);
    log('Converted back to CSV length: ${fromMsgPack.length}');
  } catch (e) {
    log('MessagePack conversion skipped or failed: $e');
  }

  log('\n=== Example Completed ===');
}
