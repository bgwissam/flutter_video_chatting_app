import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:tumble/utils/pref_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'managers/call_manager.dart';
import 'utils/configs.dart' as config;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  init(config.APP_ID, config.AUTH_KEY, config.AUTH_SECRET,
      onSessionRestore: () {
    return SharedPref.instance.init().then((pref) {
      return createSession(pref.getUser());
    });
  });
}
