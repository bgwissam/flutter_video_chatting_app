import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_call_kit/flutter_call_kit.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';

class CallKitManager {
  static CallKitManager get instance => _getInstance();
  static CallKitManager _instance;
  static String TAG = 'CallManagerKit';

  static CallKitManager _getInstance() {
    if (_instance == null) {
      _instance = CallKitManager._internal();
    }
    return _instance;
  }

  factory CallKitManager() => _getInstance();

  CallKitManager._internal() {
    this._callKit = FlutterCallKit();
  }

  FlutterCallKit _callKit;

  Function(String uuid) onCallAccepted;
  Function(String uuid) onCallEnded;
  Function(String error, String uuid, String handle,
      String localalizedCallerName, bool fromPushKit) onNewCallShown;
  Function(bool mute, String uuid) onMuteCall;

  init({
    @required onCallAccepted(uuid),
    @required onCallEnded(uuid),
    @required onNewCallShown,
    @required onMuteCall,
  }) {
    this.onCallAccepted = onCallAccepted;
    this.onCallEnded = onCallEnded;
    this.onNewCallShown = onNewCallShown;
    this.onMuteCall = onMuteCall;

    //Temporary used 'flutter_call_kit' for iOS
    _callKit.configure(
      IOSOptions(
        "P2P call sample",
        imageName: 'sim_icon',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
      ),
      performAnswerCallAction: _performAnswerCallAction,
      performEndCallAction: _performEndCallAction,
      didDisplayIncomingCall: _didDisplayIncomingCall,
      didPerformSetMutedCallAction: _didPerformSetMutedCallAction,
    );

    ConnectycubeFlutterCallKit.instance.init(
      onCallAccepted: _onCallAccepted,
      onCallRejected: _onCallRejected,
    );
  }

  //call when oponenet ends calls
  Future<void> reportEndCallWithUUID(String uuid) async {
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
    } else {
      await _callKit.reportEndCallWithUUID(uuid, EndReason.remoteEnded);
    }
  }

  Future<void> endCall(String uuid) async {
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
    } else {
      await _callKit.endCall(uuid);
    }
  }

  Future<void> rejectCall(String uuid) async {
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
    } else {
      await _callKit.rejectCall(uuid);
    }
  }

  //Event listener callbacks for 'flutter_call_kit'

  Future<void> _performAnswerCallAction(String uuid) async {
    //Called when the user answers an incoming call
    onCallAccepted.call(uuid);
  }

  Future<void> _performEndCallAction(String uuid) async {
    //Called when the user ends the call
    await _callKit.endCall(uuid);
    onCallEnded.call(uuid);
  }

  Future<void> _didDisplayIncomingCall(String error, String uuid, String handle,
      String localizedCalledName, bool fromPushKit) async {
    onNewCallShown.call(error, uuid, handle, localizedCalledName, fromPushKit);
  }

  Future<void> _didPerformSetMutedCallAction(bool mute, String uuid) {
    onMuteCall.call(mute, uuid);
  }

  //event listener for callbacks for 'connecty_cube_flutter_call_kit'

  Future<void> _onCallAccepted(String sessionId, int calltype, int callerId,
      String callerName, Set<int> oponentsIds) async {
    onCallAccepted.call(sessionId);
  }

  Future<void> _onCallRejected(String sessionId, int callType, int callerId,
      String callerName, Set<int> oponenetsId) async {
    onCallEnded.call(sessionId);
  }
}
