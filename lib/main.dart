import 'package:flutter/material.dart';
import '/subpages/signin.dart';
import '/subpages/dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sizle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      ),
      home: const ScreenManager(title: 'Sizle'),
    );
  }
}

class ScreenManager extends StatefulWidget {
  const ScreenManager({super.key, required this.title});
  final String title;

  @override
  State<ScreenManager> createState() => _ScreenManagerState();
}

class _ScreenManagerState extends State<ScreenManager> {
  String currentPage = 'signin';            // Default on signin page
  void changePageRequestManager(String nameOfNewPage) {
    setState(() {
      currentPage = nameOfNewPage;
    });
  }
  @override // 
  Widget build(BuildContext context) {
    final subpages = {
      'signin': SignInPage(title: widget.title, changePageTo: changePageRequestManager,),
      'dashboard': DashboardPage(title: widget.title, changePageTo: changePageRequestManager),
    };
    return subpages[currentPage]!;
  }
}
