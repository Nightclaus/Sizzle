import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  final String title;
  final Function(String) changePageTo;

  const DashboardPage({super.key, required this.title, required this.changePageTo});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    // Processes
    void placeholder() {}

    // Content
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: placeholder,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}