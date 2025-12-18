import 'package:flutter_csv/src/converter/mcp_converter.dart';
import 'package:test/test.dart';

void main() {
  group('McpConverter', () {
    const converter = McpConverter();

    test('toMcp wraps content correctly', () {
      final csv = 'a,b\n1,2';
      final json = converter.toMcp(csv, uri: 'test://uri', name: 'test.csv');

      expect(json, contains('"mimeType":"text/csv"'));
      expect(json, contains('"text":"a,b\\n1,2"'));
      expect(json, contains('"uri":"test://uri"'));
      expect(json, contains('"name":"test.csv"'));
    });

    test('fromMcp extracts content from simple resource', () {
      final json = '{"mimeType": "text/csv", "text": "a,b\\n1,2"}';
      final csv = converter.fromMcp(json);
      expect(csv, equals('a,b\n1,2'));
    });

    test('fromMcp extracts content from list wrapper', () {
      final json =
          '{"contents": [{"mimeType": "text/csv", "text": "a,b\\n1,2"}]}';
      final csv = converter.fromMcp(json);
      expect(csv, equals('a,b\n1,2'));
    });

    test('fromMcp throws on invalid JSON', () {
      expect(() => converter.fromMcp('{invalid}'), throwsFormatException);
    });
  });
}
