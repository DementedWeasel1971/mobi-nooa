import 'dart:async';

/// Structured SQL Query result table.
class SqlQueryResult {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final int affectedRows;

  SqlQueryResult({
    this.columns = const [],
    this.rows = const [],
    this.affectedRows = 0,
  });

  List<Map<String, dynamic>> toListOfMaps() {
    return rows.map((row) {
      final map = <String, dynamic>{};
      for (int i = 0; i < columns.length && i < row.length; i++) {
        map[columns[i]] = row[i];
      }
      return map;
    }).toList();
  }

  Map<String, dynamic> toJson() => {
        'columns': columns,
        'rowCount': rows.length,
        'affectedRows': affectedRows,
        'rows': rows,
      };

  @override
  String toString() {
    if (columns.isEmpty && affectedRows > 0) {
      return 'Query OK, $affectedRows rows affected.';
    }
    final buffer = StringBuffer();
    buffer.writeln('| ${columns.join(" | ")} |');
    buffer.writeln('| ${columns.map((_) => "---").join(" | ")} |');
    for (final row in rows.take(20)) {
      buffer.writeln('| ${row.map((e) => e.toString()).join(" | ")} |');
    }
    if (rows.length > 20) {
      buffer.writeln('... and ${rows.length - 20} more rows');
    }
    return buffer.toString().trim();
  }
}

/// Abstract contract for SQLite Database harness on mobile devices.
abstract class SqliteHarness {
  Future<void> execute(String sql, [List<dynamic>? params]);
  Future<SqlQueryResult> query(String sql, [List<dynamic>? params]);
}

/// In-memory SQL engine simulating SQLite tables and queries.
class InMemorySqliteHarness implements SqliteHarness {
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  @override
  Future<void> execute(String sql, [List<dynamic>? params]) async {
    final trimmed = sql.trim().toLowerCase();

    // CREATE TABLE tableName (col1, col2)
    if (trimmed.startsWith('create table')) {
      final match = RegExp(r'create\s+table\s+(?:if\s+not\s+exists\s+)?([a-zA-Z0-9_]+)', caseSensitive: false).firstMatch(sql);
      if (match != null) {
        final tableName = match.group(1)!;
        _tables.putIfAbsent(tableName, () => []);
      }
      return;
    }

    // INSERT INTO tableName (col1, col2, ...) VALUES (?, ?, ...)
    if (trimmed.startsWith('insert into')) {
      final colMatch = RegExp(r'insert\s+into\s+([a-zA-Z0-9_]+)\s*\(([^)]+)\)', caseSensitive: false).firstMatch(sql);
      if (colMatch != null) {
        final tableName = colMatch.group(1)!;
        final colNames = colMatch.group(2)!.split(',').map((c) => c.trim()).toList();
        _tables.putIfAbsent(tableName, () => []);

        if (params != null && params.isNotEmpty) {
          final rowMap = <String, dynamic>{};
          for (int i = 0; i < colNames.length && i < params.length; i++) {
            rowMap[colNames[i]] = params[i];
          }
          _tables[tableName]!.add(rowMap);
        }
        return;
      }

      final tableMatch = RegExp(r'insert\s+into\s+([a-zA-Z0-9_]+)', caseSensitive: false).firstMatch(sql);
      if (tableMatch != null) {
        final tableName = tableMatch.group(1)!;
        _tables.putIfAbsent(tableName, () => []);
        if (params != null && params.isNotEmpty) {
          final rowMap = <String, dynamic>{};
          for (int i = 0; i < params.length; i++) {
            rowMap['col_$i'] = params[i];
          }
          _tables[tableName]!.add(rowMap);
        }
      }
      return;
    }
  }

  @override
  Future<SqlQueryResult> query(String sql, [List<dynamic>? params]) async {
    final match = RegExp(r'from\s+([a-zA-Z0-9_]+)', caseSensitive: false).firstMatch(sql);
    if (match != null) {
      final tableName = match.group(1)!;
      var rows = List<Map<String, dynamic>>.from(_tables[tableName] ?? []);

      // Check WHERE condition
      final whereMatch = RegExp(r'where\s+([a-zA-Z0-9_]+)\s*=\s*\?', caseSensitive: false).firstMatch(sql);
      if (whereMatch != null && params != null && params.isNotEmpty) {
        final whereCol = whereMatch.group(1)!;
        final targetVal = params.first;
        rows = rows.where((r) => r[whereCol] == targetVal).toList();
      }

      if (rows.isEmpty) {
        return SqlQueryResult(columns: ['result'], rows: []);
      }

      final cols = rows.first.keys.toList();
      final tableRows = rows.map((r) => cols.map((c) => r[c]).toList()).toList();
      return SqlQueryResult(columns: cols, rows: tableRows);
    }

    return SqlQueryResult(columns: ['status'], rows: [['OK']]);
  }

  void insertRecord(String table, Map<String, dynamic> record) {
    _tables.putIfAbsent(table, () => []).add(Map.from(record));
  }
}
