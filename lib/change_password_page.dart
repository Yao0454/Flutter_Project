import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChangePasswordPage extends StatefulWidget {
  final String username;

  const ChangePasswordPage({super.key, required this.username});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  String? _errorMessage;

  Future<void> _changePassword(String username, String newPassword) async {
    final url = Uri.parse('http://www.fengqwq.cn:5001/api/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': newPassword}),
    );

    if (response.statusCode == 200) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _errorMessage = '密码更新失败，请重试';
      });
    }
  }

  void _handleChangePassword() {
    final newPassword = _newPasswordController.text.trim();

    if (newPassword.isEmpty) {
      setState(() {
        _errorMessage = '密码不能为空';
      });
      return;
    }

    _changePassword(widget.username, newPassword);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更改密码'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: '新密码'),
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
              onPressed: _handleChangePassword,
              child: const Text('更改密码'),
            ),
          ],
        ),
      ),
    );
  }
}