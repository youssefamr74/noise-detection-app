import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:noise_meter_flutter/app.dart';

ThemeMode appTheme = ThemeMode.system; //dark / light

void main()async {
  WidgetsFlutterBinding.ensureInitialized();
 await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // debugShowCheckedModeBanner: false,
      title: 'db Meter',
      home: NoiseApp(),
      darkTheme: ThemeData.dark().copyWith(),
      themeMode: appTheme,
    );
  }
}
