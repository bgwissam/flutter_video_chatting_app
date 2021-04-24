const WebRTCSession = require('./cubeWebRTCSession');
const WebRTCSignalingProcessor = require('./cubeWebRTCSignalingProcessor');
const WebRTCSignalingProvider = require('./cubeWebRTCSignalingProvider');
const Helpers = require('./cubeWebRTCHelpers');
const RTCPeerConnection = require('./cubeRTCPeerConnection');
const cubeWebRTCConstants = require('./cubeWebRTCConstants');
const SignalingConstants = cubeWebRTCConstants.SignalingConstants;
const SessionState = require('./cubeWebRTCConstants').SessionState;
const Utils = require('../cubeInternalUtils');
const mediaDevices = require('../cubeDependencies').mediaDevices;

class WebRTCClient {

  constructor(connection) {
    this.connection = connection;
    this.signalingProcessor = new WebRTCSignalingProcessor(this);
    this.signalingProvider = new WebRTCSignalingProvider(connection);

    this.SessionConnectionState = cubeWebRTCConstants.SessionConnectionState;
    this.PeerConnectionState = cubeWebRTCConstants.PeerConnectionState;
    this.CallType = cubeWebRTCConstants.CallType;

    this.sessions = {};

    if (mediaDevices) {
      mediaDevices.ondevicechange = this._onDevicesChangeListener.bind(this);
    }
  }

  getMediaDevices(spec) {
    const specDevices = []

    return new Promise((resolve, reject) => {
      if (!mediaDevices || !mediaDevices.enumerateDevices) {
        reject("No 'enumerateDevices' API supported");
      } else {
        mediaDevices.enumerateDevices().then(devices => {
          if (spec) {
            devices.forEach((device, i) => {
              if (device.kind === spec) {
                specDevices.push(device);
              }
            });
            resolve(specDevices);
          } else {
            resolve(devices);
          }
        });
      }
    });
  }

  createNewSession(opponentsIDs, callType, opts) {
    const callerID = Helpers.getUserIdFromJID(Helpers.userCurrentJid(this.connection));
    const bandwidth = opts && opts.bandwidth && (!isNaN(opts.bandwidth)) ? +opts.bandwidth : 0;
    if (!opponentsIDs) {
      throw new Error('Can\'t create a session without opponentsIDs.');
    }

    return this._createAndStoreSession(null, callerID, opponentsIDs, callType, bandwidth);
  }

  _createAndStoreSession(sessionID, initiatorID, opIDs, callType, bandwidth) {
    const newSession = new WebRTCSession({
      sessionID,
      initiatorID,
      opIDs,
      callType,
      signalingProvider: this.signalingProvider,
      currentUserID: Helpers.getUserIdFromJID(Helpers.userCurrentJid(this.connection)),
      bandwidth
    });

    newSession.onUserNotAnswerListener = this.onUserNotAnswerListener;
    newSession.onRemoteStreamListener = this.onRemoteStreamListener;
    newSession.onSessionConnectionStateChangedListener = this.onSessionConnectionStateChangedListener;
    newSession.onSessionCloseListener = this.onSessionCloseListener;
    newSession.onCallStatsReport = this.onCallStatsReport;

    this.sessions[newSession.ID] = newSession;
    return newSession;
  }

  clearSession(sessionId) {
    delete this.sessions[sessionId];
  }

  /// DELEGATE (signaling)

  _onCallListener(userID, sessionID, extension) {
    const userInfo = extension.userInfo || {};

    Helpers.trace("onCall. UserID:" + userID + ". SessionID: " + sessionID + ". extension: ", userInfo);

    let session = this.sessions[sessionID];
    const bandwidth = +userInfo.bandwidth || 0;

    if (!session) {
      session = this._createAndStoreSession(sessionID, extension.callerID, extension.opponentsIDs, extension.callType, bandwidth);
      session._processOnCall(userID, extension);
      Utils.safeCallbackCall(this.onCallListener, session, userInfo);
    } else {
      session._processOnCall(userID, extension);
    }
  }

  _onAcceptListener(userID, sessionID, extension) {
    const session = this.sessions[sessionID];
    const userInfo = extension.userInfo || {};

    Helpers.trace("onAccept. UserID:" + userID + ". SessionID: " + sessionID);

    if (session && (session.state === SessionState.ACTIVE || session.state === SessionState.NEW)) {
      Utils.safeCallbackCall(this.onAcceptCallListener, session, userID, userInfo);
      session._processOnAccept(userID, extension);
    } else {
      Helpers.traceWarning("Ignore 'onAccept', there is no information about session " + sessionID);
    }
  }

  _onRejectListener(userID, sessionID, extension) {
    const session = this.sessions[sessionID];

    Helpers.trace("onReject. UserID:" + userID + ". SessionID: " + sessionID);

    if (session) {
      const userInfo = extension.userInfo || {};
      Utils.safeCallbackCall(this.onRejectCallListener, session, userID, userInfo);
      session._processOnReject(userID, extension);
    } else {
      Helpers.traceWarning("Ignore 'onReject', there is no information about session " + sessionID);
    }
  }

  _onStopListener(userID, sessionID, extension) {
    Helpers.trace("onStop. UserID:" + userID + ". SessionID: " + sessionID);

    const session = this.sessions[sessionID];
    const userInfo = extension.userInfo || {};

    if (session && (session.state === SessionState.ACTIVE || session.state === SessionState.NEW)) {
      session._processOnStop(userID, extension);
      Utils.safeCallbackCall(this.onStopCallListener, session, userID, userInfo);
    } else {
      Utils.safeCallbackCall(this.onInvalidEventsListener, 'onStop', session, userID, userInfo);
      Helpers.traceWarning("Ignore 'onStop', there is no information about session " + sessionID + " by some reason.");
    }
  }

  _onIceCandidatesListener(userID, sessionID, extension) {
    const session = this.sessions[sessionID];

    Helpers.trace("onIceCandidates. UserID:" + userID + ". SessionID: " + sessionID + ". ICE candidates count: " + extension.iceCandidates.length);

    if (session) {
      if (session.state === SessionState.ACTIVE) {
        session._processOnIceCandidates(userID, extension);
      } else {
        Helpers.traceWarning('Ignore \'OnIceCandidates\', the session ( ' + sessionID + ' ) has invalid state.');
      }
    } else {
      Helpers.traceWarning("Ignore 'OnIceCandidates', there is no information about session " + sessionID);
    }
  }

  _onDevicesChangeListener() {
    Utils.safeCallbackCall(this.onDevicesChangeListener);
  }
}

module.exports = WebRTCClient;
