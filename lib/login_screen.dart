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

  Future _getAllUsers() async {
    List<CubeUser> users = [];
    return await getAllUsers().then((value) {
      users = value.items;
      return users;
    });
  }

  _getUserList(BuildContext context) {
    return FutureBuilder(
        future: _getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.connectionState == ConnectionState.done) {
              _isLoading = false;
              return ListView.builder(
                  itemCount: snapshot.data.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: _isLoading ? Colors.white70 : Colors.white,
                      child: ListTile(
                        title: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                snapshot.data[index].fullName,
                                style: TextStyle(
                                    color: _isLoading
                                        ? Colors.black26
                                        : Colors.black87,
                                    fontSize: 18.0),
                              ),
                              Container(
                                margin: EdgeInsets.all(8.0),
                                height: 15.0,
                                width: 15.0,
                                child: Visibility(
                                  visible: _isLoading &&
                                      snapshot.data[index].id == _selectUserId,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        onTap: () {
                          return _loginToCC(context, snapshot.data[index]);
                        },
                      ),
                    );
                  });
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Container(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator(),
                ),
              );
            } else {
              return Card(
                child: Center(
                  child: Container(
                    child: Text('Initializing...'),
                  ),
                ),
              );
            }
          } else if (snapshot.hasError) {
            return Center(
              child: Container(
                child: Text(snapshot.error),
              ),
            );
          } else {
            return Center(
              child: Container(
                child: Text('please wait!'),
              ),
            );
          }
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

    void _goSelectedOponentScreen(BuildContext context, CubeUser user) async {
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
      if (!CubeSessionManager.instance.isActiveSessionValid()) {
        createSession(loggedUser).then((cubeSession) {
          _loginToCubeChat(context, loggedUser);
        }).catchError(_processLoginError);
      } else {
        print('Logged user: $loggedUser');
        _loginToCubeChat(context, loggedUser);
        log('[LoginScree] no active user was found: ', TAG);
      }
    }
  }
}
