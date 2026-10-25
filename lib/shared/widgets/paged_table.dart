import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

class TableCol<T> {
  const TableCol(this.label, this.cell, {this.numeric = false});

  final String label;
  final Widget Function(T row) cell;
  final bool numeric;
}

/// Client-side paginated table with horizontal scrolling on narrow screens.
class PagedTable<T> extends StatefulWidget {
  const PagedTable({
    super.key,
    required this.columns,
    required this.rows,
    this.empty,
    this.pageSize = 10,
    this.showFooter = true,
  });

  final List<TableCol<T>> columns;
  final List<T> rows;
  final Widget? empty;
  final int pageSize;
  final bool showFooter;

  @override
  State<PagedTable<T>> createState() => _PagedTableState<T>();
}

class _PagedTableState<T> extends State<PagedTable<T>> {
  int _page = 0;
  late int _pageSize = widget.pageSize;

  @override
  Widget build(BuildContext context) {
    final total = widget.rows.length;
    if (total == 0) {
      return widget.empty ?? const SizedBox(height: 40);
    }
    final pages = (total / _pageSize).ceil();
    if (_page >= pages) _page = pages - 1;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, total);
    final visible = widget.rows.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 60,
                horizontalMargin: 12,
                columnSpacing: 24,
                headingRowColor: const WidgetStatePropertyAll(
                  AppColors.background,
                ),
                columns: [
                  for (final col in widget.columns)
                    DataColumn(label: Text(col.label), numeric: col.numeric),
                ],
                rows: [
                  for (final r in visible)
                    DataRow(
                      cells: [
                        for (final col in widget.columns) DataCell(col.cell(r)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.showFooter && (pages > 1 || total > 10))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('Rows per page'),
                DropdownButton<int>(
                  value: _pageSize,
                  underline: const SizedBox(),
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (n) => setState(() {
                    _pageSize = n ?? _pageSize;
                    _page = 0;
                  }),
                ),
                Text('${start + 1}–$end of $total'),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page < pages - 1
                      ? () => setState(() => _page++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
