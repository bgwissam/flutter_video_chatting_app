import 'dart:io';
import 'package:flutter/material.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';
import '../utils/configs.dart';

class CallManager {
  static String TAG = "CallManager";

  //Collects pending calls whether accepted or pending before starting chat
  Map<String, String> _callMap = {};

  static CallManager get instance => _getInstance();
  static CallManager _instance;

  static CallManager _getInstance() {
    if (_instance == null) {
      _instance = CallManager._internal();
    }
    return _instance;
  }

  factory CallManager() => _getInstance();
  CallManager._internal();

  P2PClient _callClient;
  P2PSession _currentCall;

  BuildContext context;

  init(BuildContext context) {
    this.context = context;

    _initCustomMediaConfigs();

    if (CubeChatConnection.instance.isAuthenticated()) {
      _initCalls();
    } else {
      _initChatConnectionStateListener();
    }

    _initCallKit();
  }

  destro() {
    P2PClient.instance.destroy();
    _callMap.clear();
  }

  void _initCustomMediaConfigs() {
    RTCMediaConfig mediaConfig = RTCMediaConfig.instance;
    mediaConfig.minHeight = 720;
    mediaConfig.minWidth = 1200;
    mediaConfig.minFrameRate = 30;
  }

  void _initCalls() {
    _callClient = P2PClient.instance;

    _callClient.init();

    _callClient.onReceiveNewSession = (callSession) async {
      if (_currentCall != null &&
          _currentCall.sessionId != callSession.sessionId) {
        callSession.reject();
        return;
      }
      _currentCall = callSession;

      var callState = await _getCallState(_currentCall.sessionId);

      if (callState == CallState.REJECTED) {
        reject(_currentCall.sessionId);
      } else if (callState == CallState.ACCEPTED) {
        acceptCall(_currentCall.sessionId);
      } else if (callState == CallState.UNKNOWN) {}
    };

    _callClient.onSessionClosed = (callSession) {
      if (_currentCall != null &&
          _currentCall.sessionId == callSession.sessionId) {
        _currentCall = null;
        CallKitManger.instance.reportEndCallWithUUID(callSession.sessionId);
      }
    };
  }

  //Starts a new call
  void startNewCall(BuildContext context, int callType, Set<int> opponents) {
    if (opponents.isEmpty) return;

    P2PSession callSession = _callClient.createCallSession(callType, opponents);
    _currentCall = callSession;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(callSession, false),
      ),
    );

    _sendStartCallSignalForOffliners(_currentCall);
  }

  //Go to incoming call screen
  void _showIncomingCallScreen(P2PSession callSession) {
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(callSession),
        ),
      );
    }
  }

  //Save pending call
  void _savePendingCalls(sessionId) {
    _callMap[sessionId] = CallState.PENDING;
  }

  //If call was accepted
  void acceptCall(String sessionId) {
    ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: true);
    if (_currentCall != null) {
      if (context != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => ConversationCallScreen(_currentCall, true)),
        );
      }
    } else {
      _callMap[sessionId] = CallState.ACCEPTED;
    }
  }

  //If call was rejected
  void reject(String sessionId) {
    if (_currentCall != null) {
      CallKitManager.instance.rejectCall(_currentCall.sessionId);
      _currentCall.reject();
    } else {
      _callMap[sessionId] = CallState.REJECTED;
    }
  }

  //If the caller ended the call
  void hungUp() {
    if (_currentCall != null) {
      CallKitManager.instance.endCall(_currentCall.sessionId);
      _sendEndCallSignalForOffLiners(_currentCall);
      _currentCall.hungUp();
    }
  }

  CreateEventParams _getCallEvenetParameters(P2PSession currentCall) {
    String callerName = users
        .where((cubeUser) => cubeUser.id == currentCall.callerId)
        .first
        .fullName;

    CreateEventParams params = CreateEventParams();
    params.parameters = {
      'message':
          "Incoming ${currentCall.callType == CallType.VIDEO_CALL ? "Video" : "Audio"} call",
      PARAM_CALL_TYPE: currentCall.callType,
      PARAM_SEESION_ID: currentCall.sessionId,
      PARAM_CALLER_ID: currentCall.callerId,
      PARAM_CALLER_NAME: callerName,
      PARAM_CALL_OPPONENTS: currentCall.opponentsIds.join(','),
      PARAM_IOS_VOID: 1,
    };

    params.notificationType = NotificationType.PUSH;
    params.environment =
        CubeEnvironment.DEVELOPMENT; //This is for development stage only

    // bool isProduction = bool.fromEnvironment('dart.vm.products');
    // params.environment =
    //     isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
    params.usersIds = currentCall.opponentsIds.toList();

    return params;
  }

  //will send a report for offliners on starting a call session
  void _sendStartCallSignalForOffliners(P2PSession currentCall) {
    CreateEventParams params = _getCallEvenetParameters(currentCall);
    params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_START_CALL;

    createEvent(params.getEventForRequest()).then((cubeEvent) {
      log('Event for offliners created');
    }).catchError((error) {
      log('Error occured during call creation: $error');
    });
  }

  //Will send a report of offliners on ending a call session
  void _sendEndCallSignalForOffliners(P2PSession currentCall) {
    CubeUser currentUser = CubeChatConnection.instance.currentUser;
    if (currentUser != null && currentUser.id != currentCall.callerId) {
      return;
    }

    CreateEventParams params = _getCallEvenetParameters(currentCall);
    params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_END_CALL;

    createEvent(params.getEventForRequest()).then((cubeEvent) {
      log('Event of offliners created');
    }).catchError((error) {
      log('Error occured during event creation: $error');
    });
  }

  void _initCallKit() {
    CallKitManager.instance.init(
      onCallAccepted: (uuid) {
        acceptCall(uuid);
      },
      onCallEnded: (uuid) {
        hungUp();
      },
      onNewCallShown: (error, uuid, handle, callerName, fromPushKit) {
        _savePendingCalls(uuid);
      },
      onMuteCall: (mute, uuid) {
        _currentCall?.setMicrophoneMute(mute);
      },
    );
  }

  void _initChatConnectionStateListener() {
    CubeChatConnection.instance.connectionStateStream.listen(
      (state) {
        if (CubeChatConnectionState.Ready == state) {
          _initCalls();
        }
      },
    );
  }

  Future<String> _getCallState(String sessionId) async {
    if (Platform.isAndroid) {
      return ConnectycubeFlutterCallKit.getCallState(sessionId: sessionId);
    } else if (Platform.isIOS) {
      if (_callMap.containsKey(sessionId)) {
        return Future.value(_callMap[sessionId]);
      }
    }

    return Future.value(CallState.UNKNOWN);
  }
}
