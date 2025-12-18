import 'package:flutter_csv/flutter_csv.dart';
import 'package:flutter_csv/src/converter/mcp_schema_converter.dart';
import 'package:test/test.dart';

void main() {
  group('McpSchemaConverter', () {
    const converter = McpSchemaConverter();

    group('Tools', () {
      test('convertTools parses valid CSV correctly', () {
        final csv = CsvDocument.fromCsv(
          'tool_name,tool_description,arg_name,arg_type,required\n'
          'weather,Get weather,city,string,true\n'
          'weather,Get weather,days,number,false\n'
          'calculator,Add numbers,a,number,true',
          firstRowIsHeader: true,
        );

        final tools = converter.convertTools(csv);

        expect(tools.length, 2);

        final weather = tools.firstWhere((t) => t['name'] == 'weather');
        expect(weather['description'], 'Get weather');
        expect(weather['inputSchema']['required'], contains('city'));
        expect(weather['inputSchema']['properties']['city']['type'], 'string');
        expect(weather['inputSchema']['properties']['days']['type'], 'number');

        final calculator = tools.firstWhere((t) => t['name'] == 'calculator');
        expect(calculator['inputSchema']['required'], contains('a'));
      });

      test('convertTools throws on missing headers', () {
        final csv = CsvDocument.fromCsv('a,b', firstRowIsHeader: false);
        expect(() => converter.convertTools(csv), throwsFormatException);
      });
    });

    group('Resources', () {
      test('convertResources parses valid CSV correctly', () {
        final csv = CsvDocument.fromCsv(
          'uri,name,description,type\n'
          'file:///a.txt,A,File A,text/plain\n'
          'file:///b.json,B,File B,application/json',
          firstRowIsHeader: true,
        );

        final resources = converter.convertResources(csv);

        expect(resources.length, 2);
        expect(resources[0]['uri'], 'file:///a.txt');
        expect(resources[0]['name'], 'A');
        expect(resources[0]['mimeType'], 'text/plain');

        expect(resources[1]['uri'], 'file:///b.json');
        expect(resources[1]['mimeType'], 'application/json');
      });
    });

    group('Prompts', () {
      test('convertPrompts parses valid CSV correctly', () {
        final csv = CsvDocument.fromCsv(
          'prompt_name,role,content\n'
          'greeting,system,You are helpful\n'
          'greeting,user,Hello',
          firstRowIsHeader: true,
        );

        final prompts = converter.convertPrompts(csv);

        expect(prompts.length, 1);
        final greeting = prompts.first;
        expect(greeting['name'], 'greeting');
        expect(greeting['messages'], hasLength(2));
        expect(greeting['messages'][0]['role'], 'system');
        expect(greeting['messages'][1]['content']['text'], 'Hello');
      });

      test('convertPrompts throws on invalid role', () {
        final csv = CsvDocument.fromCsv(
          'prompt_name,role,content\n'
          'test,invalid_role,hi',
          firstRowIsHeader: true,
        );
        expect(() => converter.convertPrompts(csv), throwsFormatException);
      });
    });
  });
}
