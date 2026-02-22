import 'package:flutter/material.dart';
import 'router_demo.dart'; // make sure this path matches your file name

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: RouterDemo(),
    );
  }
}