import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'excel_page.dart'; 
import 'settings_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'change_password_page.dart';

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
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(fetchUsernames: fetchUsernames),
        '/change_password': (context) => ChangePasswordPage(
              username: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/home': (context) => const MyHomePage(title: '成绩查询'),
        '/profile': (context) => ProfilePage(
              username: ModalRoute.of(context)!.settings.arguments as String,
            ),
      },
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
  int _currentIndex = 0; // 当前选中的页面索引
  late Future<List<TileData>> _futureTileData;
  List<String> _usernames = [];
  String? _errorMessage;

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
  }

  Future<void> _refreshUsernames() async {
    try {
      final usernames = await fetchUsernames();
      setState(() {
        _usernames = usernames;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '无法刷新用户名列表，请检查网络连接。';
      });
    }
  }

  Future<String> _getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentUsername') ?? '未知用户';
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomePage(
        futureTileData: _futureTileData,
        refreshData: _refreshData,
        getCurrentUsername: _getCurrentUsername,
      ),
      ProfilePage(
        username: ModalRoute.of(context)!.settings.arguments as String,
      ),  // 个人页面
      const SettingsPage(), // 设置页面
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '个人',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
          
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Future<List<TileData>> futureTileData;
  final Future<void> Function() refreshData;
  final Future<String> Function() getCurrentUsername;

  const HomePage({super.key, required this.futureTileData, required this.refreshData, required this.getCurrentUsername});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主页'), // 标题栏内容
        centerTitle: true, // 标题居中
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final username = prefs.getString('currentUsername') ?? '未知用户';
              Navigator.pushNamed(
                context,
                '/profile',
                arguments: username,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshData, // 下滑刷新时调用
        child: FutureBuilder<List<TileData>>(
          future: futureTileData,
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

Future<List<String>> fetchUsernames() async {
  final url = Uri.parse('http://www.fengqwq.cn:5001/api/usernames');
  print('Fetching usernames from: $url'); // 打印请求的 URL
  final response = await http.get(url);
  print('Response status: ${response.statusCode}'); // 打印响应状态码
  if (response.statusCode == 200) {
    return List<String>.from(json.decode(response.body)); // 返回用户名列表
  } else {
    throw Exception('无法加载用户名');
  }
}
