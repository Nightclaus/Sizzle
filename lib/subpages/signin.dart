import 'package:flutter/material.dart';

class SignInPage extends StatefulWidget {
  final String title;
  final Function(String) changePageTo;

  const SignInPage({super.key, required this.title, required this.changePageTo});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
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