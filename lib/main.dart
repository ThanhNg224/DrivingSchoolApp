// lib/main.dart

import 'package:flutter/material.dart';
import 'pages/login_screen.dart';
import 'pages/video_screen.dart';
void main() {
  runApp(const DrivingSchoolApp());
}

class DrivingSchoolApp extends StatelessWidget {
  const DrivingSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving School App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
