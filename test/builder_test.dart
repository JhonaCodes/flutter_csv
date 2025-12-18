import 'package:flutter_csv/flutter_csv.dart';
import 'package:test/test.dart';

void main() {
  group('CsvBuilder', () {
    group('basic building', () {
      test('builds empty CSV', () {
        final doc = FlutterCsv.builder().build();

        expect(doc.isEmpty, isTrue);
        expect(doc.toCsv(), isEmpty);
      });

      test('builds CSV with columns and rows', () {
        final builder = FlutterCsv.builder()
          ..columns(['Name', 'Age'])
          ..row(['John', 30])
          ..row(['Jane', 25]);
        final doc = builder.build();

        expect(doc.hasHeaders, isTrue);
        expect(doc.headers, ['Name', 'Age']);
        expect(doc.rowCount, 2);
        expect(doc.toCsv(), 'Name,Age\nJohn,30\nJane,25');
      });

      test('builds CSV without headers', () {
        final builder = FlutterCsv.builder()
          ..row(['a', 'b', 'c'])
          ..row([1, 2, 3]);
        final doc = builder.build();

        expect(doc.hasHeaders, isFalse);
        expect(doc.rowCount, 2);
      });

      test('adds multiple rows at once', () {
        final builder = FlutterCsv.builder()
          ..rows([
            ['a', 'b'],
            ['c', 'd'],
            ['e', 'f'],
          ]);
        final doc = builder.build();

        expect(doc.rowCount, 3);
      });
    });

    group('fluent settings', () {
      test('uses field delimiter', () {
        final csv = (FlutterCsv.builder()
              ..fieldDelimiter(';')
              ..row(['a', 'b', 'c']))
            .export();

        expect(csv, 'a;b;c');
      });

      test('uses text delimiter', () {
        final csv = (FlutterCsv.builder()
              ..textDelimiter("'")
              ..quoteAllFields(true)
              ..row(['a', 'b']))
            .export();

        expect(csv, "'a','b'");
      });

      test('uses EOL', () {
        final csv = (FlutterCsv.builder()
              ..eol('\r\n')
              ..row(['a'])
              ..row(['b']))
            .export();

        expect(csv, 'a\r\nb');
      });

      test('applies preset settings', () {
        final builder = FlutterCsv.builder()
          ..rfc4180()
          ..row(['a', 'b']);
        final doc = builder.build();

        expect(doc.settings.eol, '\r\n');
      });
    });

    group('from maps', () {
      test('builds from single map', () {
        final builder = FlutterCsv.builder()
          ..fromMap({'name': 'John', 'age': 30});
        final doc = builder.build();

        expect(doc.hasHeaders, isTrue);
        expect(doc.headers, containsAll(['name', 'age']));
        expect(doc.rowCount, 1);
      });

      test('builds from multiple maps', () {
        final builder = FlutterCsv.builder()
          ..fromMaps([
            {'name': 'John', 'age': 30},
            {'name': 'Jane', 'age': 25},
          ]);
        final doc = builder.build();

        expect(doc.rowCount, 2);
      });

      test('handles maps with different keys', () {
        final builder = FlutterCsv.builder()
          ..fromMaps([
            {'name': 'John', 'age': 30},
            {'name': 'Jane', 'city': 'NYC'},
          ]);
        final doc = builder.build();

        expect(doc.headers, containsAll(['name', 'age', 'city']));
      });
    });

    group('column operations', () {
      test('adds column with values', () {
        final builder = FlutterCsv.builder()
          ..row(['a', 'b'])
          ..row(['c', 'd'])
          ..addColumn('New', ['x', 'y']);
        final doc = builder.build();

        expect(doc.headers, ['New']);
        expect(doc.getColumn(2), ['x', 'y']);
      });
    });

    group('quick export', () {
      test('exports directly to string', () {
        final csv = (FlutterCsv.builder()
              ..columns(['A', 'B'])
              ..row([1, 2]))
            .export();

        expect(csv, 'A,B\n1,2');
      });
    });

    group('builder state', () {
      test('reports row count', () {
        final builder = FlutterCsv.builder()
          ..row([1])
          ..row([2])
          ..row([3]);

        expect(builder.rowCount, 3);
      });

      test('reports column count', () {
        final builder = FlutterCsv.builder()..columns(['a', 'b', 'c']);

        expect(builder.columnCount, 3);
      });

      test('clears data', () {
        final builder = FlutterCsv.builder()
          ..columns(['a'])
          ..row([1])
          ..clear();

        expect(builder.rowCount, 0);
        expect(builder.hasHeaders, isFalse);
      });
    });
  });

  group('CsvDocument', () {
    group('creation', () {
      test('creates from CSV string', () {
        const csv = 'a,b,c\n1,2,3';
        final doc = CsvDocument.fromCsv(csv);

        expect(doc.rowCount, 2);
        expect(doc.hasHeaders, isFalse);
      });

      test('creates from CSV with headers', () {
        const csv = 'Name,Age\nJohn,30';
        final doc = CsvDocument.fromCsv(csv, firstRowIsHeader: true);

        expect(doc.headers, ['Name', 'Age']);
        expect(doc.rowCount, 1);
      });

      test('creates from maps', () {
        final doc = CsvDocument.fromMaps([
          {'a': 1, 'b': 2},
          {'a': 3, 'b': 4},
        ]);

        expect(doc.hasHeaders, isTrue);
        expect(doc.rowCount, 2);
      });
    });

    group('data access', () {
      late CsvDocument doc;

      setUp(() {
        doc = CsvDocument.fromCsv(
          'Name,Age\nJohn,30\nJane,25',
          firstRowIsHeader: true,
        );
      });

      test('gets row by index', () {
        expect(doc.getRow(0), ['John', '30']);
        expect(doc.getRow(1), ['Jane', '25']);
        expect(doc.getRow(2), isNull);
      });

      test('gets cell by coordinates', () {
        expect(doc.getCell(0, 0), 'John');
        expect(doc.getCell(0, 1), '30');
      });

      test('gets cell by header', () {
        expect(doc.getCellByHeader(0, 'Name'), 'John');
        expect(doc.getCellByHeader(0, 'Age'), '30');
      });

      test('gets column by index', () {
        expect(doc.getColumn(0), ['John', 'Jane']);
      });

      test('gets column by header', () {
        expect(doc.getColumnByHeader('Name'), ['John', 'Jane']);
      });
    });

    group('header manipulation', () {
      test('promotes first row to headers', () {
        const csv = 'Name,Age\nJohn,30';
        final doc = CsvDocument.fromCsv(csv);
        final withHeaders = doc.promoteFirstRowToHeaders();

        expect(withHeaders.headers, ['Name', 'Age']);
        expect(withHeaders.rowCount, 1);
      });

      test('demotes headers to first row', () {
        const csv = 'Name,Age\nJohn,30';
        final doc = CsvDocument.fromCsv(csv, firstRowIsHeader: true);
        final withoutHeaders = doc.demoteHeadersToFirstRow();

        expect(withoutHeaders.hasHeaders, isFalse);
        expect(withoutHeaders.rowCount, 2);
      });
    });
  });

  group('List extension', () {
    test('creates builder from list', () {
      final builder = [
        ['a', 'b'],
        [1, 2],
      ].toCsvBuilder();

      expect(builder.rowCount, 2);
    });

    test('creates builder with first row as header', () {
      final builder = [
        ['Name', 'Age'],
        ['John', 30],
      ].toCsvBuilder(firstRowIsHeader: true);

      expect(builder.hasHeaders, isTrue);
      expect(builder.rowCount, 1);
    });
  });
}
