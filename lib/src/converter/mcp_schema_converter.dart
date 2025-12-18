import '../builder/csv_document.dart';

/// Converts structured CSV data into valid MCP (Model Context Protocol) JSON configurations.
///
/// Supports converting tables into:
/// - Tools (with JSON Schema arguments)
/// - Resources
/// - Prompts (with roles and content)
class McpSchemaConverter {
  const McpSchemaConverter();

  // ----------------------------------------------------------------------
  // TOOLS
  // ----------------------------------------------------------------------

  /// Converts CSV to MCP Tools definition.
  ///
  /// Expected columns:
  /// - tool_name
  /// - tool_description
  /// - arg_name
  /// - arg_type (string, number, boolean, object, array)
  /// - required (true/false)
  List<Map<String, dynamic>> convertTools(CsvDocument document) {
    if (!document.hasHeaders) {
      throw FormatException(
          'CSV must have headers to be converted to MCP Tools');
    }

    final toolsMap = <String, Map<String, dynamic>>{};

    // Helper to get required column index
    int getColIndex(String name) {
      final idx = document.headers!.indexOf(name);
      if (idx == -1) throw FormatException('Missing required column: $name');
      return idx;
    }

    final nameIdx = getColIndex('tool_name');
    final descIdx = getColIndex('tool_description');
    final argNameIdx = getColIndex('arg_name');
    final argTypeIdx = getColIndex('arg_type');
    final reqIdx = getColIndex('required');

    for (final row in document.data) {
      final toolName = row[nameIdx]?.toString().trim();
      if (toolName == null || toolName.isEmpty) continue;

      if (!toolsMap.containsKey(toolName)) {
        toolsMap[toolName] = {
          'name': toolName,
          'description': row[descIdx]?.toString().trim() ?? '',
          'inputSchema': {
            'type': 'object',
            'properties': <String, dynamic>{},
            'required': <String>[],
          }
        };
      }

      final argName = row[argNameIdx]?.toString().trim();
      if (argName != null && argName.isNotEmpty) {
        final argType =
            row[argTypeIdx]?.toString().trim().toLowerCase() ?? 'string';
        final isRequired = row[reqIdx]?.toString().toLowerCase() == 'true';

        final tool = toolsMap[toolName]!;
        final schema = tool['inputSchema'] as Map<String, dynamic>;
        final props = schema['properties'] as Map<String, dynamic>;
        final reqList = schema['required'] as List<String>;

        props[argName] = {'type': argType};
        if (isRequired) {
          reqList.add(argName);
        }
      }
    }

    return toolsMap.values.toList();
  }

  // ----------------------------------------------------------------------
  // RESOURCES
  // ----------------------------------------------------------------------

  /// Converts CSV to MCP Resources definition.
  ///
  /// Expected columns:
  /// - uri
  /// - type (optional, defaults to text/plain if missing)
  /// - description (optional)
  List<Map<String, dynamic>> convertResources(CsvDocument document) {
    if (!document.hasHeaders) {
      throw FormatException(
          'CSV must have headers to be converted to MCP Resources');
    }

    int getColIndex(String name) {
      final idx = document.headers!.indexOf(name);
      if (idx == -1) throw FormatException('Missing required column: $name');
      return idx;
    }

    final uriIdx = getColIndex('uri');
    final typeIdx = document.headers!.indexOf('type');
    final descIdx = document.headers!.indexOf('description');
    final nameIdx = document.headers!.indexOf('name');

    final resources = <Map<String, dynamic>>[];

    for (final row in document.data) {
      final uri = row[uriIdx]?.toString().trim();
      if (uri == null || uri.isEmpty) continue;

      final resource = <String, dynamic>{
        'uri': uri,
        'mimeType': typeIdx != -1
            ? (row[typeIdx]?.toString().trim() ?? 'text/plain')
            : 'text/plain',
      };

      if (nameIdx != -1) {
        final val = row[nameIdx]?.toString().trim();
        if (val != null && val.isNotEmpty) resource['name'] = val;
      }

      if (descIdx != -1) {
        final val = row[descIdx]?.toString().trim();
        if (val != null && val.isNotEmpty) resource['description'] = val;
      }

      resources.add(resource);
    }

    return resources;
  }

  // ----------------------------------------------------------------------
  // PROMPTS
  // ----------------------------------------------------------------------

  /// Converts CSV to MCP Prompts definition.
  ///
  /// Expected columns:
  /// - prompt_name
  /// - role (user, assistant, system)
  /// - content
  List<Map<String, dynamic>> convertPrompts(CsvDocument document) {
    if (!document.hasHeaders) {
      throw FormatException(
          'CSV must have headers to be converted to MCP Prompts');
    }

    int getColIndex(String name) {
      final idx = document.headers!.indexOf(name);
      if (idx == -1) throw FormatException('Missing required column: $name');
      return idx;
    }

    final nameIdx = getColIndex('prompt_name');
    final roleIdx = getColIndex('role');
    final contentIdx = getColIndex('content');

    final promptsMap = <String, Map<String, dynamic>>{};

    for (final row in document.data) {
      final promptName = row[nameIdx]?.toString().trim();
      if (promptName == null || promptName.isEmpty) continue;

      if (!promptsMap.containsKey(promptName)) {
        promptsMap[promptName] = {
          'name': promptName,
          'messages': <Map<String, dynamic>>[],
        };
      }

      final role = row[roleIdx]?.toString().trim().toLowerCase();
      final content = row[contentIdx]?.toString().trim();

      if (role != null && content != null) {
        if (!['user', 'assistant', 'system'].contains(role)) {
          throw FormatException(
              'Invalid role: $role. Must be user, assistant, or system.');
        }

        (promptsMap[promptName]!['messages'] as List).add({
          'role': role,
          'content': {
            'type': 'text',
            'text': content,
          }
        });
      }
    }

    return promptsMap.values.toList();
  }
}
