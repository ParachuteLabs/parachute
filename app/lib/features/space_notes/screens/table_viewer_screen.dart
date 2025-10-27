import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/providers/api_provider.dart';
import 'package:app/core/models/table_query_result.dart';
import 'dart:convert';

final tableDataProvider = FutureProvider.family<TableQueryResult, TableQueryParams>(
  (ref, params) async {
    final apiClient = ref.read(apiClientProvider);
    return apiClient.getTableData(params.spaceId, params.tableName);
  },
);

class TableQueryParams {
  final String spaceId;
  final String tableName;

  TableQueryParams({required this.spaceId, required this.tableName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableQueryParams &&
          runtimeType == other.runtimeType &&
          spaceId == other.spaceId &&
          tableName == other.tableName;

  @override
  int get hashCode => spaceId.hashCode ^ tableName.hashCode;
}

class TableViewerScreen extends ConsumerWidget {
  final String spaceId;
  final String tableName;

  const TableViewerScreen({
    super.key,
    required this.spaceId,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TableQueryParams(spaceId: spaceId, tableName: tableName);
    final tableDataAsync = ref.watch(tableDataProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text(tableName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(tableDataProvider(params));
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: tableDataAsync.when(
        data: (tableData) {
          if (tableData.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No rows in this table'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Table info header
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(Icons.table_rows, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${tableData.rowCount} rows × ${tableData.columns.length} columns',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              // Scrollable table
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.primaryContainer,
                      ),
                      columns: tableData.columns.map((col) {
                        return DataColumn(
                          label: Text(
                            col,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      rows: tableData.rows.map((row) {
                        return DataRow(
                          cells: tableData.columns.map((col) {
                            final value = row[col];
                            return DataCell(
                              _buildCellContent(context, value),
                              onTap: () => _copyToClipboard(context, value),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading table'),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(BuildContext context, dynamic value) {
    if (value == null) {
      return Text(
        'NULL',
        style: TextStyle(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Handle JSON objects/arrays
    if (value is Map || value is List) {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(value);
      return Container(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Text(
          jsonStr,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Theme.of(context).colorScheme.secondary,
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // Handle numbers
    if (value is num) {
      return Text(
        value.toString(),
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }

    // Handle strings
    final strValue = value.toString();

    // Format timestamps (Unix timestamps)
    if (value is int && value > 1000000000 && value < 2000000000) {
      final date = DateTime.fromMillisecondsSinceEpoch(value * 1000);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strValue,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Text(
        strValue,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(BuildContext context, dynamic value) {
    String textToCopy;
    if (value == null) {
      textToCopy = 'NULL';
    } else if (value is Map || value is List) {
      textToCopy = const JsonEncoder.withIndent('  ').convert(value);
    } else {
      textToCopy = value.toString();
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
