import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:tumble/select_oponent_screen.dart';
import 'package:tumble/utils/pref_utils.dart';

import 'utils/configs.dart' as utils;

class LoginScreen extends StatefulWidget {
  static const String TAG = 'LoginScreen';

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Video Calling'),
      ),
      body: BodyLayout(),
    );
  }
}

class BodyLayout extends StatefulWidget {
  @override
  BodyState createState() {
    return BodyState();
  }
}

class BodyState extends State<BodyLayout> {
  static const String TAG = 'LoginScreen.BodyState';
  bool _isLoading = false;
  int _selectUserId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(36.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select user to begin:',
            style: TextStyle(fontSize: 18.0),
          ),
          Expanded(child: _getUserList(context))
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    SharedPref.instance.init().then((pref) {
      CubeUser loggedUser = pref.getUser();
      if (loggedUser != null) {
        _loginToCC(context, loggedUser);
      }
    });
  }

  _getUserList(BuildContext context) {
    final users = utils.users;

    return ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          return Card(
            color: _isLoading ? Colors.white70 : Colors.white,
            child: ListTile(
              title: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      users[index].fullName,
                      style: TextStyle(
                          color: _isLoading ? Colors.black26 : Colors.black87,
                          fontSize: 18.0),
                    ),
                    Container(
                      margin: EdgeInsets.all(8.0),
                      height: 15.0,
                      width: 15.0,
                      child: Visibility(
                        visible: _isLoading && users[index].id == _selectUserId,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              onTap: () {
                return _loginToCC(context, users[index]);
              },
            ),
          );
        });
  }

  _loginToCC(BuildContext context, CubeUser loggedUser) {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _selectUserId = loggedUser.id;
    });

    void _processLoginError(exception) {
      log('Login error: $exception', TAG);

      setState(() {
        _isLoading = false;
        _selectUserId = 0;
      });

      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Login Error'),
              content: Text(
                  'Something went wrong, please try again later or contact support'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close'))
              ],
            );
          });
    }

    void _goSelectedOponentScreen(BuildContext context, CubeUser user) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SelectOponentScreen(
                    currentUser: user,
                  )));
    }

    void _loginToCubeChat(BuildContext context, CubeUser user) {
      CubeChatConnection.instance.login(user).then((cubeUser) {
        SharedPref.instance.init().then((prefs) {
          prefs.saveNewUser(user);
        });
        setState(() {
          _isLoading = false;
          _selectUserId = 0;
        });
        _goSelectedOponentScreen(context, cubeUser);
      }).catchError(_processLoginError);
    }

    if (CubeSessionManager.instance.isActiveSessionValid() &&
        CubeSessionManager.instance.activeSession.user != null) {
      if (CubeChatConnection.instance.isAuthenticated()) {
        setState(() {
          _isLoading = false;
          _selectUserId = 0;
        });
        _goSelectedOponentScreen(context, loggedUser);
      } else {
        _loginToCubeChat(context, loggedUser);
      }
    } else {
      print('Session :${CubeSessionManager.instance.isActiveSessionValid()} ');
      createSession(loggedUser).then((cubeSession) {
        _loginToCubeChat(context, loggedUser);
      }).catchError(_processLoginError);
    }
  }
}
