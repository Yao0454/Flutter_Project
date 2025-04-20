import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<String>> fetchUsernames() async {
  final url = Uri.parse('http://www.fengqwq.cn:5001/api/usernames');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return List<String>.from(json.decode(response.body));
  } else {
    throw Exception('无法加载用户名');
  }
}

class LoginPage extends StatefulWidget {
  final Future<List<String>> Function() fetchUsernames;

  const LoginPage({super.key, required this.fetchUsernames});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  List<String> _usernames = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsernames();
  }

  Future<void> _loadUsernames() async {
    try {
      final usernames = await widget.fetchUsernames();
      setState(() {
        _usernames = usernames;
        _errorMessage = null; // 清除错误信息
      });
    } catch (e) {
      setState(() {
        _errorMessage = '无法加载用户名，请检查网络连接。';
      });
    }
  }

  Future<void> _refreshUsernames() async {
    await _loadUsernames();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '用户名和密码不能为空';
      });
      return;
    }

    final url = Uri.parse('http://www.fengqwq.cn:5001/api/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUsername', username);

      if (password == '0000') {
        Navigator.pushReplacementNamed(
          context,
          '/change_password',
          arguments: username,
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _errorMessage = json.decode(response.body)['error'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsernames, // 下滑刷新时调用
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              '提示：默认密码为 0000，请登录后及时更改密码。',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: '用户名'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: const Text('登录'),
            ),
            const SizedBox(height: 16),
            if (_usernames.isEmpty) // 仅当用户名列表为空时显示提示
              const Text(
                '下滑刷新以更新用户名列表',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshUsernames, // 点击刷新按钮时调用
        child: const Icon(Icons.refresh),
        tooltip: '刷新用户名列表',
      ),
    );
  }
}