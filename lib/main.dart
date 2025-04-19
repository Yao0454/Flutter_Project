import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
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
    _requestPermissions();
    _futureTileData = fetchTileData();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.storage.isDenied) {
      final status = await Permission.storage.request();
      if (status.isPermanentlyDenied) {
        // 引导用户到设置页面
        openAppSettings();
      }
    }
  }

  Future<List<TileData>> fetchTileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverIp = prefs.getString('serverIp') ?? '10.0.2.2'; // 默认 IP 地址
      const apiEndpoint = '/api/tiles'; // 固定的 API 端点

      final url = Uri.parse('http://$serverIp:5001$apiEndpoint');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => TileData.fromJson(json)).toList();
      } else {
        throw Exception('服务端返回错误状态码: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('无法连接到服务端，请检查 IP 地址或域名是否正确: $e');
    } catch (e) {
      throw Exception('发生未知错误: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _futureTileData = fetchTileData();
    });
    //await _futureTileData; // 等待数据加载完成
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
              // 返回支持刷新的错误提示视图
              return ListView(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 100),
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          '加载失败: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '请检查网络连接或服务器地址，然后下拉刷新重试。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // 返回支持刷新的空数据提示视图
              return ListView(
                children: const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Text('没有数据', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              );
            } else {
              final tiles = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: tiles.length,
                itemBuilder: (context, index) {
                  final tile = tiles[index];
                  return GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final serverIp = prefs.getString('serverIp') ?? '10.0.2.2'; // 默认 IP 地址
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExcelPage(
                            title: tile.title,
                            excelUrl: 'http://$serverIp:5001/api/excel/stream/${Uri.encodeComponent(tile.title)}',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
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
