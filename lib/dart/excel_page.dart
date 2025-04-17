import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExcelPage extends StatefulWidget {
  final String title;
  final String excelUrl; // Excel 文件的 URL

  const ExcelPage({super.key, required this.title, required this.excelUrl});

  @override
  State<ExcelPage> createState() => _ExcelPageState();
}

class _ExcelPageState extends State<ExcelPage> {
  late Stream<List<Map<String, dynamic>>> _excelDataStream;
  List<Map<String, dynamic>> _allRows = []; // 保存所有数据
  List<Map<String, dynamic>> _filteredRows = []; // 保存过滤后的数据
  int _currentPage = 0; // 当前页码
  final int _rowsPerPage = 10; // 每页显示的行数
  String _searchQuery = ""; // 搜索关键字

  @override
  void initState() {
    super.initState();
    _excelDataStream = fetchExcelDataStream(widget.excelUrl);
    _excelDataStream.listen((rows) {
      setState(() {
        _allRows = rows;
        _filteredRows = rows; // 初始化时显示所有数据
      });
    });
  }

  Stream<List<Map<String, dynamic>>> fetchExcelDataStream(String url) async* {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        List<Map<String, dynamic>> rows = [];
        await for (String line in streamedResponse.stream.transform(utf8.decoder).transform(LineSplitter())) {
          if (line.trim().isNotEmpty) { // 过滤空行
            try {
              final Map<String, dynamic> jsonData = json.decode(line);
              // 替换 null 值为默认值
              jsonData.forEach((key, value) {
                if (value == null) {
                  jsonData[key] = ""; // 或者设置为 "N/A"
                }
              });
              rows.add(jsonData);
            } catch (e) {
              print('Invalid JSON line: $line'); // 打印无效的 JSON 数据
            }
          }
        }
        yield rows;
      } else {
        throw Exception('Failed to load Excel data: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      print('Error fetching Excel data: $e');
      rethrow;
    }
  }

  void _search(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredRows = _allRows;
      } else {
        _filteredRows = _allRows
            .where((row) => row.values.any((value) => value.toString().toLowerCase().contains(query.toLowerCase())))
            .toList();
      }
      _currentPage = 0; // 搜索后重置到第一页
    });
  }

  @override
  Widget build(BuildContext context) {
    // 动态计算每页显示的行数
    final double rowHeight = 56.0; // 每行的高度（DataTable 默认行高）
    final double availableHeight = MediaQuery.of(context).size.height - 200; // 可用高度（减去搜索栏和其他控件的高度）
    final int rowsPerPage = (availableHeight / rowHeight).floor(); // 动态计算每页行数

    final columns = _filteredRows.isNotEmpty ? _filteredRows.first.keys.toList() : [];
    final startIndex = _currentPage * rowsPerPage;
    final endIndex = (_currentPage + 1) * rowsPerPage;
    final currentRows = _filteredRows.sublist(
      startIndex,
      endIndex > _filteredRows.length ? _filteredRows.length : endIndex,
    );
    final totalPages = (_filteredRows.length / rowsPerPage).ceil(); // 总页数

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '搜索',
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _filteredRows.isEmpty
                ? const Center(
                    child: Text('没有数据'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: columns
                          .map((column) => DataColumn(
                                label: Text(
                                  column,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ))
                          .toList(),
                      rows: currentRows
                          .map((row) => DataRow(
                                cells: columns
                                    .map((column) => DataCell(
                                          Text(row[column].toString()),
                                        ))
                                    .toList(),
                              ))
                          .toList(),
                    ),
                  ),
          ),
          // 翻页控件
          if (_filteredRows.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('第 ${_currentPage + 1} 页 / 共 $totalPages 页'),
                SizedBox(
                  width: 50,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '跳转',
                      contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                    ),
                    onSubmitted: (value) {
                      final page = int.tryParse(value);
                      if (page != null && page > 0 && page <= totalPages) {
                        setState(() {
                          _currentPage = page - 1;
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: endIndex < _filteredRows.length
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
        ],
      ),
    );
  }
}