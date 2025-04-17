import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _apiEndpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverAddressController.text = prefs.getString('serverAddress') ?? '';
      _apiEndpointController.text = prefs.getString('apiEndpoint') ?? '';
    });
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    _apiEndpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '服务端设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serverAddressController,
              decoration: const InputDecoration(
                labelText: '服务端地址',
                hintText: '例如：http://10.0.2.2:5001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiEndpointController,
              decoration: const InputDecoration(
                labelText: 'API 端点',
                hintText: '例如：/api/tiles',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('serverAddress', _serverAddressController.text);
                  await prefs.setString('apiEndpoint', _apiEndpointController.text);

                  print('设置已保存');
                  Navigator.pop(context);
                },
                child: const Text('保存设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}