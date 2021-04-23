import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:flutter/material.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import 'managers/call_manager.dart';

class ConversationCallScreen extends StatefulWidget {
  final P2PSession _callSession;
  final bool _isIncoming;
  @override
  _ConversationCallScreenState createState() {
    return _ConversationCallScreenState(_callSession, _isIncoming);
  }

  ConversationCallScreen(this._callSession, this._isIncoming);
}

class _ConversationCallScreenState extends State<ConversationCallScreen>
    implements RTCSessionStateCallback<P2PSession> {
  static const String TAG = '_conversationalCallScreenState';
  P2PSession _callSession;
  bool _isIncoming;
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;
  Map<int, RTCVideoRenderer> streams = {};

  _ConversationCallScreenState(this._callSession, this._isIncoming);

  @override
  void initState() {
    super.initState();

    _callSession.onLocalStreamReceived = _addLocalMediaStream;
    _callSession.onRemoteStreamReceived = _addRemoteMediaStream;
    _callSession.onSessionClosed = _onSessionClosed;

    _callSession.setSessionCallbacksListener(this);
    if (_isIncoming) {
      _callSession.acceptCall();
    } else {
      _callSession.startCall();
    }
  }

  @override
  void dispose() {
    super.dispose();
    streams.forEach((oponentId, stream) async {
      log('[dispose] dispose rendered for $oponentId', TAG);
      await stream.dispose();
    });
  }

  //For local media streaming
  void _addLocalMediaStream(MediaStream stream) {
    log('_addLocalMediaStream', TAG);
    _onStreamAdd(CubeChatConnection.instance.currentUser.id, stream);
  }

  //For remote medial streaming
  void _addRemoteMediaStream(session, int userId, MediaStream stream) {
    log('_addRemoteMediaStream', TAG);
    _onStreamAdd(userId, stream);
  }

  //Remove media stream
  void _removeMediaStream(callSession, int userId) {
    log('_removeMediaStream for user $userId', TAG);
    RTCVideoRenderer videoRenderer = streams[userId];
    if (videoRenderer == null) return;

    videoRenderer.srcObject = null;
    videoRenderer.dispose();
    setState(() {
      streams.remove(userId);
    });
  }

  //Closing the current session
  void _onSessionClosed(session) {
    log('_onSessionClosed', TAG);
    _callSession.removeSessionCallbacksListener();

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  void _onStreamAdd(int opponenetId, MediaStream stream) async {
    log('_onStreamAdd for user $opponenetId', TAG);

    RTCVideoRenderer streamRender = RTCVideoRenderer();
    await streamRender.initialize();
    streamRender.srcObject = stream;
    setState(() {
      streams[opponenetId] = streamRender;
    });
  }

  //Build the media stream grid
  List<Widget> renderStreamGrid(Orientation orientation) {
    List<Widget> streamExpanded = streams.entries
        .map(
          (entry) => Expanded(
            child: RTCVideoView(
              entry.value,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: true,
            ),
          ),
        )
        .toList();

    if (streams.length > 2) {
      List<Widget> rows = [];
      for (var i = 0; i < streamExpanded.length; i += 2) {
        var chunkEndIndex = i + 2;

        if (streamExpanded.length < chunkEndIndex) {
          chunkEndIndex = streamExpanded.length;
        }

        var chunk = streamExpanded.sublist(i, chunkEndIndex);

        rows.add(
          Expanded(
            child: orientation == Orientation.portrait
                ? Row(
                    children: chunk,
                  )
                : Column(
                    children: chunk,
                  ),
          ),
        );
      }
      return rows;
    }
    return streamExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Stack(
        children: [
          Scaffold(
            body: _isVideoCall()
                ? OrientationBuilder(
                    builder: (context, orientation) {
                      return Center(
                        child: Container(
                          child: orientation == Orientation.portrait
                              ? Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: renderStreamGrid(orientation),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: renderStreamGrid(orientation),
                                ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Text(
                            'Audio Call',
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Members',
                            style: TextStyle(
                                fontSize: 20, fontStyle: FontStyle.italic),
                          ),
                        ),
                        Text(
                          _callSession.opponentsIds.join(', '),
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _getActionPanel(),
          ),
        ],
      ),
    );
  }

  Widget _getActionPanel() {
    return Container(
      margin: EdgeInsets.only(bottom: 16, left: 8, right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32.0),
        child: Container(
          padding: EdgeInsets.all(4),
          color: Colors.black26,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              //Mic muting
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: 'Mute',
                  child: Icon(
                    Icons.mic,
                    color: _isMicMute ? Colors.grey : Colors.white,
                  ),
                  onPressed: () => _muteMic(),
                  backgroundColor: Colors.black38,
                ),
              ),
              //switching speaker
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: 'Speaker',
                  child: Icon(
                    Icons.volume_up,
                    color: _isSpeakerEnabled ? Colors.grey : Colors.white,
                  ),
                  onPressed: () => _switchSpeaker(),
                  backgroundColor: Colors.black38,
                ),
              ),
              //Switch camera
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: 'SwitchCamera',
                  child: Icon(
                    Icons.switch_video,
                    color: _isCameraEnabled ? Colors.grey : Colors.white,
                  ),
                  onPressed: () => _switchCamera(),
                  backgroundColor: Colors.black38,
                ),
              ),
              //Toggle Camera
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: 'ToggleCamera',
                  child: Icon(
                    Icons.videocam,
                    color: _isVideoEnabled() ? Colors.grey : Colors.white,
                  ),
                  onPressed: () => _toggleCamera(),
                  backgroundColor: Colors.black38,
                ),
              ),
              Expanded(
                child: SizedBox(),
                flex: 1,
              ),
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: FloatingActionButton(
                  child: Icon(Icons.call_end, color: Colors.white),
                  backgroundColor: Colors.red,
                  onPressed: () => _endCall(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  _endCall() {
    CallManager.instance.hungUp();
  }

  Future<bool> _onBackPressed(BuildContext context) {
    return Future.value(false);
  }

  _muteMic() {
    setState(() {
      _isMicMute = !_isMicMute;
      _callSession.setMicrophoneMute(_isMicMute);
    });
  }

  _switchCamera() {
    if (!_isVideoEnabled()) return;

    _callSession.switchCamera();
  }

  _toggleCamera() {
    if (!_isVideoEnabled()) return;

    setState(() {
      _isCameraEnabled = !_isCameraEnabled;
      _callSession.setVideoEnabled(_isCameraEnabled);
    });
  }

  bool _isVideoEnabled() {
    return _isVideoCall() && _isCameraEnabled;
  }

  bool _isVideoCall() {
    return CallType.VIDEO_CALL == _callSession.callType;
  }

  _switchSpeaker() {
    setState(() {
      _isSpeakerEnabled = !_isCameraEnabled;
      _callSession.enableSpeakerphone(_isSpeakerEnabled);
    });
  }

  @override
  void onConnectedToUser(P2PSession session, int userId) {
    log('onConnectedToUser userId: $userId');
  }

  @override
  void onConnectionClosedForUser(P2PSession session, int userId) {
    log('onConnectionClosedForUser userId: $userId');
    _removeMediaStream(session, userId);
  }

  @override
  void onDisconnectedFromUser(P2PSession session, int userId) {
    log('onDisconnectedFromUser userId: $userId');
  }
}
