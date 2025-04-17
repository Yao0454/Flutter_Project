import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'excel_page.dart'; 
import 'settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 0, 0),
          primary: const Color.fromARGB(255, 0, 0, 0), // 主色
          onPrimary: const Color.fromARGB(255, 54, 47, 47), // AppBar标题颜色
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 218, 91, 91), // AppBar背景色
          titleTextStyle: TextStyle(
            color: Colors.white, // 标题颜色
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const MyHomePage(title: '成绩查询'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<List<TileData>> _futureTileData;

  @override
  void initState() {
    super.initState();
    _futureTileData = fetchTileData();
  }

  Future<List<TileData>> fetchTileData() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:5001/api/tiles'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => TileData.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _futureTileData = fetchTileData();
    });
    await _futureTileData; // 等待数据加载完成
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData, // 下滑刷新时调用
        child: FutureBuilder<List<TileData>>(
          future: _futureTileData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('加载失败: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('没有数据'));
            } else {
              final tiles = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: tiles.length,
                itemBuilder: (context, index) {
                  final tile = tiles[index];
                  return GestureDetector(
                    onTap: () {
                      // 跳转到 Excel 页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExcelPage(
                            title: tile.title,
                            excelUrl: 'http://10.0.2.2:5001/api/excel/stream/${Uri.encodeComponent(tile.title)}',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 87, 196, 141),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tile.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tile.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tile.extraInfo,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
      // 添加右下角的圆形设置按钮
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 跳转到设置页面
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          );
        },
        child: const Icon(Icons.settings),
      ),
    );
  }
}

// 数据模型类
class TileData {
  final String title;
  final String description;
  final String extraInfo;

  TileData({required this.title, required this.description, required this.extraInfo});

  factory TileData.fromJson(Map<String, dynamic> json) {
    return TileData(
      title: json['title'] ?? "", // 如果为 null，则使用空字符串
      description: json['description'] ?? "",
      extraInfo: json['extraInfo'] ?? "",
    );
  }
}
