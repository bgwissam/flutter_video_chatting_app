import 'dart:io';
import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:flutter/material.dart';
import 'package:device_id/device_id.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/managers/call_manager.dart';
import 'package:flutter_application_1/utils/constants.dart';
import 'package:flutter_application_1/utils/pref_utils.dart';
import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';

import '../utils/configs.dart' as config;

class PushNotificationsManager {
  static const TAG = 'PushNotificationsManager';
  static final PushNotificationsManager _instance =
      PushNotificationsManager._internal();

  PushNotificationsManager._internal() {
    Firebase.initializeApp();
  }

  BuildContext applicationContext;
  static PushNotificationsManager get instance => _instance;

  FlutterVoipPushNotification _voipPush = FlutterVoipPushNotification();

  init() async {
    if (Platform.isAndroid) {
      _initFcm();
    } else if (Platform.isIOS) {
      _initIosVoIP();
    }

    FirebaseMessaging.onMessage.listen((remoteMessage) async {
      processCallNotification(remoteMessage.data);
    });

    FirebaseMessaging.onBackgroundMessage(onBackGroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((remoteMessage) {
      log('[onMessageOpened] remoteMessage: $remoteMessage', TAG);
    });
  }

  _initIosVoIP() async {
    await _voipPush.requestNotificationPermissions();
    _voipPush.configure(onMessage: onMessage, onResume: onResume);

    _voipPush.onTokenRefresh.listen((token) {
      log('[onTokenRefresh] VoIP token: $token', TAG);
      subscribe(token);
    });
  }

  _initFcm() async {
    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    await firebaseMessaging.requestPermission(
        alert: true, badge: true, sound: true);

    firebaseMessaging.getToken().then((token) {
      log('[getToken] FCM Token: $token', TAG);
      subscribe(token);
    }).catchError((error) {
      log('[getToken] error: $error', TAG);
    });

    firebaseMessaging.onTokenRefresh.listen((newToken) {
      log('[onTokenRefresh] onTokenRefresh: $newToken', TAG);
      subscribe(newToken);
    });
  }

  subscribe(String token) async {
    log('[Subscribe] token: $token', PushNotificationsManager.TAG);

    SharedPref sharedPref = await SharedPref.instance.init();

    if (sharedPref.getSubscriptionToken() == token) {
      log('[subscribe] skip subscription for same token: $token',
          PushNotificationsManager.TAG);
      return;
    }

    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    parameters.environment =
        CubeEnvironment.DEVELOPMENT; //This is just for testing
    //For development purpose
    // parameters.environment = _isProduction
    //     ? CubeEnvironment.PRODUCTION
    //     : CubeEnvironment.DEVELOPMENT;
    if (Platform.isAndroid) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
      parameters.bundleIdentifier =
          'com.connectycube.flutter.flutter_application_1';
    } else if (Platform.isIOS) {
      parameters.channel = NotificationsChannels.APNS_VOIP;
      parameters.platform = CubePlatform.IOS;
      parameters.bundleIdentifier =
          'com.connectycube.flutter.flutter_application_1';
    }

    String deviceId = await DeviceId.getID;
    parameters.udid = deviceId;
    parameters.pushToken = token;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscription) {
      log('[subscribe] subscribe Success ', PushNotificationsManager.TAG);
      sharedPref.saveSubscriptionToken(token);
      cubeSubscription.forEach((subscription) {
        if (subscription.device.clientIdentificationSequence == token) {
          sharedPref.saveSubscriptionId(subscription.id);
        }
      });
    }).catchError((error) {
      log('[subscribe] subscription error: $error',
          PushNotificationsManager.TAG);
    });
  }

  Future<dynamic> unsubscribe() {
    return SharedPref.instance.init().then((sharedPref) async {
      int subscriptionId = sharedPref.getSubscriptionId();
      if (subscriptionId != 0) {
        return deleteSubscription(subscriptionId).then((voidResut) {
          FirebaseMessaging.instance.deleteToken();
          sharedPref.saveSubscriptionId(0);
        });
      } else {
        return Future.value();
      }
    }).catchError((error) {
      log('[unsubscribe] Error: $error', PushNotificationsManager.TAG);
    });
  }
}

Future<dynamic> onMessage(bool isLocal, Map<String, dynamic> payLoad) {
  log('[onMessage] received on foreground payLoad: $payLoad, isLocal: $isLocal',
      PushNotificationsManager.TAG);

  processCallNotification(payLoad);

  return null;
}

Future<dynamic> onResume(bool isLocal, Map<String, dynamic> payLoad) async {
  log('[onMessage] received on background payLoad: $payLoad, isLocal: $isLocal',
      PushNotificationsManager.TAG);

  return null;
}

processCallNotification(Map<String, dynamic> data) async {
  log('[processCallNotification] message: $data', PushNotificationsManager.TAG);

  String signalType = data[PARAM_SIGNAL_TYPE];
  String sessionId = data[PARAM_SESSION_ID];
  Set<int> oponentsIds = (data[PARAM_CALL_OPPONENTS] as String)
      .split(',')
      .map((e) => int.parse(e))
      .toSet();

  if (signalType == SIGNAL_TYPE_START_CALL) {
    ConnectycubeFlutterCallKit.showCallNotification(
        sessionId: sessionId,
        callType: int.parse(data[PARAM_CALL_TYPE]),
        callerId: int.parse(data[PARAM_CALLER_ID]),
        callerName: data[PARAM_CALLER_NAME],
        opponentsIds: oponentsIds);
  } else if (signalType == SIGNAL_TYPE_END_CALL) {
    ConnectycubeFlutterCallKit.reportCallEnded(
        sessionId: data[PARAM_SESSION_ID]);
  } else if (signalType == SIGNAL_TYPE_REJECT_CALL) {
    if (oponentsIds.length == 1) {
      CallManager.instance.hungUp();
    }
  }
}

Future<void> onBackGroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();

  ConnectycubeFlutterCallKit.onCallAcceptedWhenTerminated =
      (sessionId, callType, callerId, callerName, oponenetsIds) {
    return sendPushAboudRejectFromKillState({
      PARAM_CALL_TYPE: callType,
      PARAM_SESSION_ID: sessionId,
      PARAM_CALLER_ID: callerId,
      PARAM_CALLER_NAME: callerName,
      PARAM_CALL_OPPONENTS: oponenetsIds.join(',')
    }, callerId);
  };
  ConnectycubeFlutterCallKit.initMessagesHandler();

  processCallNotification(message.data);

  return Future.value();
}

Future<void> sendPushAboudRejectFromKillState(
    Map<String, dynamic> parameters, int callerId) {
  CubeSettings.instance.applicationId = config.APP_ID;
  CubeSettings.instance.authorizationKey = config.AUTH_KEY;
  CubeSettings.instance.authorizationSecret = config.AUTH_SECRET;
  CubeSettings.instance.accountKey = config.ACCOUNT_ID;
  CubeSettings.instance.onSessionRestore = () {
    return SharedPref.instance.init().then((preferences) {
      return createSession(preferences.getUser());
    });
  };

  CreateEventParams params = CreateEventParams();
  params.parameters = parameters;
  params.parameters['message'] = 'Reject call';
  params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_REJECT_CALL;
  params.parameters[PARAM_IOS_VOIP] = 1;

  params.notificationType = NotificationType.PUSH;
  params.environment = CubeEnvironment.DEVELOPMENT; //For testing purppse only

  // params.environment =
  //     _isProductsion ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
  params.usersIds = [callerId];
  return createEvent(params.getEventForRequest());
}
