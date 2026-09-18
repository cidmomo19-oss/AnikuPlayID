import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Tentang Aplikasi'),
            subtitle: const Text('AnikuPlay v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Backend Server'),
            subtitle: const Text('Cloudflare Worker & D1 Database'),
          ),
        ],
      ),
    );
  }
}
