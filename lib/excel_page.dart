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

  // 用于存储用户的筛选选择
  final Set<String> _selectedClasses = {};

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
        // 如果搜索框为空，显示筛选后的数据
        _filteredRows = _selectedClasses.isNotEmpty
            ? _allRows.where((row) => _selectedClasses.contains(row['班级']?.toString())).toList()
            : _allRows;
      } else {
        // 基于筛选后的数据进行搜索
        _filteredRows = _allRows
            .where((row) =>
                (_selectedClasses.isEmpty || _selectedClasses.contains(row['班级']?.toString())) &&
                row.values.any((value) => value.toString().toLowerCase().contains(query.toLowerCase())))
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

    final columns = _filteredRows.isNotEmpty
        ? _filteredRows.first.keys.map((key) => key.toString()).toList() as List<String>
        : <String>[];
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
          // 搜索栏和筛选按钮
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '搜索',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _search,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _showFilterDialog(context, columns);
                  },
                  child: const Text('筛选'),
                ),
              ],
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

  void _showFilterDialog(BuildContext context, List<String> columns) {
    // 找到包含“班级”字样的列
    final classColumn = columns.firstWhere(
      (column) => column.contains('班级'),
      orElse: () => '',
    );

    if (classColumn.isEmpty) {
      // 如果没有找到“班级”列，显示提示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('未找到包含“班级”字样的列'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    // 获取所有班级的值并排序
    final classValues = _allRows
        .map((row) => row[classColumn]?.toString() ?? '') // 确保值为字符串
        .where((value) => value.isNotEmpty) // 过滤空值
        .toSet()
        .toList()
      ..sort((a, b) => int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ?? a.compareTo(b)); // 按数字排序

    // 创建一个临时变量来存储当前对话框中的选择
    final tempSelectedClasses = Set<String>.from(_selectedClasses);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('筛选班级'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: classValues.map((value) {
                    return CheckboxListTile(
                      title: Text(value),
                      value: tempSelectedClasses.contains(value),
                      onChanged: (isChecked) {
                        setState(() {
                          if (isChecked == true) {
                            tempSelectedClasses.add(value);
                          } else {
                            tempSelectedClasses.remove(value);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // 关闭对话框
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    // 更新全局筛选选择
                    setState(() {
                      _selectedClasses
                        ..clear()
                        ..addAll(tempSelectedClasses);

                      // 更新表格内容
                      if (_selectedClasses.isNotEmpty) {
                        _filteredRows = _allRows
                            .where((row) => _selectedClasses.contains(row[classColumn]?.toString()))
                            .toList();
                      } else {
                        _filteredRows = _allRows; // 如果没有选择任何选项，显示所有数据
                      }
                      _currentPage = 0; // 重置到第一页
                    });

                    // 刷新页面
                    this.setState(() {});

                    Navigator.pop(context); // 关闭对话框
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}