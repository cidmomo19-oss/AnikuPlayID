import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../services/anikuplay_api_service.dart';

class AnikuPlayApp extends StatefulWidget {
  const AnikuPlayApp({super.key});

  @override
  State<AnikuPlayApp> createState() => _AnikuPlayAppState();
}

class _AnikuPlayAppState extends State<AnikuPlayApp> {
  int _selectedIndex = 0;
  final AnikuPlayApiService _apiService = AnikuPlayApiService();

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(apiService: _apiService),
      const SettingsScreen(),
    ];

    return MaterialApp(
      title: 'AnikuPlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: Scaffold(
        body: pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey,
          backgroundColor: const Color(0xFF1E1E1E),
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
