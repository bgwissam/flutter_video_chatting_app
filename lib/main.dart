import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'managers/call_manager.dart';
import 'src/util/configs.dart' as config;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.deepPurpleAccent,
      ),
      home: Builder(
        builder: (context) {
          CallManager.instance.init(context);

          return LoginScreen();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    Firebase.initializeApp();
    initConnectyCube();
  }
}

initConnectyCube() {
  init(APP_ID);
}
