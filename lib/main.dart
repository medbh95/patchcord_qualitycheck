import 'package:flutter/material.dart';
import 'app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PatchCordQualityCheck',
      home: PatchCordQualityCheck(),
      debugShowCheckedModeBanner: false,
    );
  }
}
