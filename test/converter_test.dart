import 'package:flutter_csv/flutter_csv.dart';
import 'package:test/test.dart';

void main() {
  group('CsvToJsonConverter', () {
    group('basic conversion', () {
      test('converts CSV to JSON with headers', () {
        const csv = 'Name,Age\nJohn,30\nJane,25';
        final json = FlutterCsv.toJson(csv);

        expect(json, contains('Name'));
        expect(json, contains('John'));
        expect(json, contains('30'));
      });

      test('converts CSV to JSON without headers', () {
        const csv = 'John,30\nJane,25';
        final json = FlutterCsv.toJson(csv, firstRowIsHeader: false);

        expect(json, contains('column_1'));
        expect(json, contains('John'));
      });

      test('converts to pretty JSON', () {
        const csv = 'Name,Age\nJohn,30';
        final json = FlutterCsv.toJson(csv, pretty: true);

        expect(json, contains('\n'));
        expect(json, contains('  '));
      });
    });

    group('to maps', () {
      test('converts CSV to list of maps', () {
        const csv = 'Name,Age\nJohn,30\nJane,25';
        final maps = FlutterCsv.toMaps(csv);

        expect(maps.length, 2);
        expect(maps[0]['Name'], 'John');
        expect(maps[0]['Age'], '30');
        expect(maps[1]['Name'], 'Jane');
      });

      test('handles missing values', () {
        const csv = 'Name,Age,City\nJohn,30';
        final maps = FlutterCsv.toMaps(csv);

        expect(maps[0]['City'], isNull);
      });
    });
  });

  group('JsonToCsvConverter', () {
    group('from JSON', () {
      test('converts JSON array to CSV', () {
        const json = '[{"name":"John","age":30},{"name":"Jane","age":25}]';
        final csv = FlutterCsv.fromJson(json);

        expect(csv, contains('name'));
        expect(csv, contains('John'));
        expect(csv, contains('30'));
      });

      test('converts JSON object to CSV', () {
        const json = '{"name":"John","age":30}';
        final csv = FlutterCsv.fromJson(json);

        expect(csv, contains('name'));
        expect(csv, contains('John'));
      });

      test('converts without headers', () {
        const json = '[{"name":"John","age":30}]';
        final csv = FlutterCsv.fromJson(json, includeHeaders: false);

        expect(csv, isNot(contains('name')));
        expect(csv, contains('John'));
      });
    });

    group('from maps', () {
      test('converts list of maps to CSV', () {
        final csv = FlutterCsv.fromMaps([
          {'name': 'John', 'age': 30},
          {'name': 'Jane', 'age': 25},
        ]);

        expect(csv, contains('name'));
        expect(csv, contains('John'));
        expect(csv, contains('Jane'));
      });

      test('handles empty list', () {
        final csv = FlutterCsv.fromMaps([]);

        expect(csv, isEmpty);
      });
    });
  });

  group('Round-trip conversion', () {
    test('CSV -> JSON -> CSV preserves data', () {
      const original = 'Name,Age\nJohn,30\nJane,25';
      final json = FlutterCsv.toJson(original);
      final restored = FlutterCsv.fromJson(json);

      expect(restored, contains('John'));
      expect(restored, contains('30'));
      expect(restored, contains('Jane'));
      expect(restored, contains('25'));
    });

    test('Maps -> CSV -> Maps preserves data', () {
      final original = [
        {'name': 'John', 'age': 30},
        {'name': 'Jane', 'age': 25},
      ];

      final csv = FlutterCsv.fromMaps(original);
      final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);
      final restored = doc.toMaps();

      expect(restored.length, 2);
      expect(restored[0]['name'], 'John');
    });
  });

  group('Extension methods', () {
    test('toJson extension', () {
      final data = [
        ['John', 30],
        ['Jane', 25],
      ];

      final json = data.toJson(headers: ['Name', 'Age']);

      expect(json, contains('Name'));
      expect(json, contains('John'));
    });

    test('toMaps extension', () {
      final data = [
        ['John', 30],
        ['Jane', 25],
      ];

      final maps = data.toMaps(['Name', 'Age']);

      expect(maps[0]['Name'], 'John');
      expect(maps[0]['Age'], 30);
    });
  });
}
