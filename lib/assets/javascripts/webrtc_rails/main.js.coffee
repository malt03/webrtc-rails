class @WebRTC
  @DISCONNECTED: 0
  @TIMEOUT: 1
  @CALLING: 2

  myUserIdentifier: null
  remoteUserIdentifier: null

  onWebSocketConnected: ->
  onWebSocketReconnectingStarted: ->
  onWebSocketReconnected: ->
  onWebRTCCall: (remoteUserIdentifier) ->
  onWebRTCConnected: ->
  onWebRTCReconnectingStarted: ->
  onWebRTCReconnected: ->
  onWebRTCHangedUp: ->
  onWebRTCConnectFailed: (reason) ->
  onServerMessage: (message) ->
  onUserMessage: (sentUserIdentifier, event, message) ->
  onSendUserMessageFailed: (sendUserIdentifier, event, message) ->

  constructor: (url, userToken, localOutput, remoteOutput) ->
    @localOutput = if localOutput? then (localOutput[0] || localOutput) else null
    @remoteOutput = remoteOutput[0] || remoteOutput
    @_startOutput(@localOutput)
    @_webSocketInitialize(url, userToken)
    @_addNetworkEventListener()

    window.onbeforeunload = (e) =>
      if @_hangedUp then null else '通話が切断されます。'

    onunload = window.onunload
    window.onunload = (e) =>
      if onunload?
         onunload()
      unless @_hangedUp
        @hangUp()

  call: (remoteUserIdentifier) ->
    if @_webRTCReconnecting && @_hangedUp
      @_webRTCReconnecting = false
      return

    @_isCaller = true
    @remoteUserIdentifier = remoteUserIdentifier
    if !@_peerStarted && @_localStream
      @_sendMessage(
        type: 'call'
        remoteUserIdentifier: @myUserIdentifier
        reconnect: @_webRTCReconnecting
      )
      @_callAnswerReceived = false
      window.setTimeout(
        =>
          unless @_callAnswerReceived
            if @_webRTCReconnecting
              @call(remoteUserIdentifier)
            else
              @onWebRTCConnectFailed(WebRTC.TIMEOUT)
        5000
      )
    else
      alert 'Local stream not running yet - try again.'

  answer: ->
    @_isCaller = false
    @_sendOffer()
    @_peerStarted = true

  sendUserMessage: (userIdentifier, event, message) ->
    @_sendValue('userMessage',
      userIdentifier: String(userIdentifier)
      event: event
      message: message
    )

  enableVideo: ->
    @setVideoEnabled(true)

  disableVideo: ->
    @setVideoEnabled(false)

  setVideoEnabled: (enabled) ->
    unless @_localStream?
      @_wantSetVideoEnabled = true
      @_videoEnabled = enabled
      return
    for track in @_localStream.getVideoTracks()
      track.enabled = enabled

  enableAudio: ->
    @setAudioEnabled(true)

  disableAudio: ->
    @setAudioEnabled(false)

  setAudioEnabled: (enabled) ->
    unless @_localStream?
      @_wantSetAudioEnabled = true
      @_audioEnabled = enabled
      return
    for track in @_localStream.getAudioTracks()
      track.enabled = enabled

  hangUp: ->
    @_sendMessage(type: 'hangUp')
    @_hangUp()

  readyState: ->
    unless @_webSocket?
      return WebSocket.CLOSED
    return @_webSocket.readyState
  # private

  _hangedUp: true
  _localStream: null
  _peerConnection: null
  _peerStarted: false
  _mediaConstraints: 'mandatory':
    'OfferToReceiveAudio': true
    'OfferToReceiveVideo': true

  _RTCIceCandidate: window.RTCIceCandidate || window.mozRTCIceCandidate || window.webkitRTCIceCandidate || window.msRTCIceCandidate
  _RTCSessionDescription: window.RTCSessionDescription || window.mozRTCSessionDescription || window.webkitRTCSessionDescription || window.msRTCSessionDescription
  _RTCPeerConnection: window.RTCPeerConnection || window.mozRTCPeerConnection || window.webkitRTCPeerConnection || window.msRTCPeerConnection

  _webSocketInitialize: (url, userToken) ->
    @_userToken = userToken
    @_webSocket = new WebSocket(url)
    @_webSocket.onopen = =>
      @_startHeartbeat()
      @_sendValue('setMyToken')
      if @_wantWebRTCReconnecting
        @_wantWebRTCReconnecting = false
        @call(@remoteUserIdentifier)

    @_webSocket.onclose = (event) =>
      unless @_isWebSocketReconnectingStarted
        @_isWebSocketReconnectingStarted = true
        @onWebSocketReconnectingStarted()
      @_webSocketInitialize(url, userToken)

    @_webSocket.onmessage = (data) =>
      event = JSON.parse(data.data)
      eventType = event['type']

      dontNeedRemoteUserCheckType = ['userMessage', 'userMessageFailed', 'myUserIdentifier', 'call', 'webSocketReconnected']
      if dontNeedRemoteUserCheckType.indexOf(eventType) == -1
        if @remoteUserIdentifier != event['remoteUserIdentifier']
          return

      switch eventType
        when 'userMessage'
          @onUserMessage(event['remoteUserIdentifier'], event['event'], event['message'])
        when 'userMessageFailed'
          @onSendUserMessageFailed(event['remoteUserIdentifier'], event['event'], event['message'])
        when 'myUserIdentifier'
          @myUserIdentifier = event['myUserIdentifier']
          if @_webSocketConnected
            @onWebSocketReconnected()
            if @_hangedUp
              @_sendMessage(type: 'hangUp')
            else
              @_sendMessage(type: 'webSocketReconnected')
          else
            @onWebSocketConnected()
            @_webSocketConnected = true
        when 'webSocketReconnected'
          if @_hangedUp || @remoteUserIdentifier != event['remoteUserIdentifier']
            @_sendMessageToOther(type: 'hangUp', event['remoteUserIdentifier'])
        when 'callFailed'
          @_callAnswerReceived = true
          @onWebRTCConnectFailed(event['reason'] || WebRTC.UNKNOWN)
        when 'call'
          if @_peerStarted
            message =
              type: 'callFailed'
              reason: WebRTC.CALLING
            @_sendMessageToOther(message, event['remoteUserIdentifier'])
          else if event['reconnect'] && @_hangedUp
            @_sendMessage(type: 'hangUp')
          else
            @remoteUserIdentifier = event['remoteUserIdentifier']
            @onWebRTCCall(@remoteUserIdentifier)
        when 'hangUp'
          @_callAnswerReceived = true
          @_hangUp()
        when 'offer'
          @_callAnswerReceived = true
          @_webRTCReconnecting = false
          @_onOffer(event)
        when 'answer'
          if @_peerStarted
            @_onAnswer(event)
        when 'candidate'
          if @_peerStarted
            @_onCandidate(event)
        when 'serverMessage'
          @onServerMessage(event['message'])
        when 'userMessage'
          @onUserMessage(event['userType'], event['message'])

  _addNetworkEventListener: ->
    window.addEventListener('offline', (event) =>
      @_webSocket.close()
    )

  _startHeartbeat: ->
    if !@_heartbeating
      @_heartbeating = true
      @_heartbeat()

  _heartbeat: ->
    @_sendValue('heartbeat', null)
    window.setTimeout(
      =>
        @_heartbeat()
      5000
    )

  _sendValue: (event, value) ->
    if @_webSocket.readyState == WebSocket.OPEN
      @_webSocket.send(JSON.stringify(
        token: @_userToken
        event: event
        value: value
      ))

  _sendMessageToOther: (message, userIdentifier) ->
    @_sendValue('sendMessage',
      userIdentifier: String(userIdentifier)
      message: message
    )
    
  _sendMessage: (message) ->
    @_sendMessageToOther(message, @remoteUserIdentifier)

  _startOutput: (localOutput) ->
    isVideo = (@localOutput? && @localOutput.tagName.toUpperCase() == 'VIDEO')
    navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia
    navigator.getUserMedia(
      video: isVideo
      audio: true
      (stream) =>
        @_localStream = stream
        if @localOutput?
          @localOutput.src = window.URL.createObjectURL(@_localStream)
          @localOutput.play()
          @localOutput.volume = 0
          if @_wantSetVideoEnabled
            @setVideoEnabled(@_videoEnabled)
          if @_wantSetAudioEnabled
            @setAudioEnabled(@_audioEnabled)
      (error) =>
        console.error('An error occurred: [CODE ' + error.code + ']')
    )

  _onOffer: (event) ->
    @_setOffer(event)
    @_sendAnswer(event)
    @_peerStarted = true

  _onAnswer: (event) ->
    @_setAnswer(event)

  _onCandidate: (event) ->
    candidate = new @_RTCIceCandidate(
      sdpMLineIndex: event.sdpMLineIndex
      sdpMid: event.sdpMid
      candidate: event.candidate
    )
    @_peerConnection.addIceCandidate(candidate)

  _sendSDP: (sdp) ->
    @_sendMessage(sdp)

  _sendCandidate: (candidate) ->
    @_sendMessage(candidate)

  _prepareNewConnection: ->
    pcConfig = 'iceServers': [ "urls": "stun:stun.l.google.com:19302" ]
    peer = null

    onRemoteStreamAdded = (event) =>
      @remoteOutput.src = window.URL.createObjectURL(event.stream)

    onRemoteStreamRemoved = (event) =>
      @remoteOutput.src = ''

    try
      peer = new @_RTCPeerConnection(pcConfig)
    catch e
      console.log('Failed to create peerConnection, exception: ' + e.message)

    peer.onicecandidate = (event) =>
      if event.candidate
        @_sendCandidate(
          type: 'candidate'
          sdpMLineIndex: event.candidate.sdpMLineIndex
          sdpMid: event.candidate.sdpMid
          candidate: event.candidate.candidate
        )

    peer.oniceconnectionstatechange = (event) =>
      switch peer.iceConnectionState
        when 'disconnected'
          @_reconnectPeer()
          @onWebRTCReconnectingStarted()
        when 'checking'
          @_checking = true
        when 'connected', 'completed'
          if @_checking
            @_checking = false
            if @_hangedUp
              @onWebRTCConnected()
              @_hangedUp = false
            else
              @onWebRTCReconnected()

    peer.addStream(@_localStream)
    peer.addEventListener('addstream', onRemoteStreamAdded, false)
    peer.addEventListener('removestream', onRemoteStreamRemoved, false)
    peer

  _reconnectPeer: ->
    @_stop()
    if @_isCaller
      @_webRTCReconnecting = true
      if @_webSocket.readyState == WebSocket.OPEN
        @call(@remoteUserIdentifier)
      else 
        @_wantWebRTCReconnecting = true

  _sendOffer: ->
    @_peerConnection = @_prepareNewConnection()
    @_peerConnection.createOffer(
      (sessionDescription) =>
        @_peerConnection.setLocalDescription(sessionDescription)
        @_sendSDP(sessionDescription)
      ->
        console.log('Create Offer failed')
      @_mediaConstraints
    )

  _setOffer: (event) ->
    if @_peerConnection
      console.error('peerConnection alreay exist!')
    @_peerConnection = @_prepareNewConnection()
    @_peerConnection.setRemoteDescription(new @_RTCSessionDescription(event))

  _sendAnswer: (event) ->
    if !@_peerConnection
      console.error('peerConnection NOT exist!')
      return
    @_peerConnection.createAnswer(
      (sessionDescription) =>
        @_peerConnection.setLocalDescription(sessionDescription)
        @_sendSDP(sessionDescription)
      ->
        console.log('Create Answer failed')
      @_mediaConstraints
    )

  _setAnswer: (event) ->
    if !@_peerConnection
      console.error('peerConnection NOT exist!')
      return
    @_peerConnection.setRemoteDescription(new @_RTCSessionDescription(event))

  _hangUp: ->
    @_stop()
    @_hangedUp = true
    @onWebRTCHangedUp()
    @remoteUserIdentifier = null

  _stop: ->
    if @_peerConnection?
      @_peerConnection.close()
      @_peerConnection = null
    @_peerStarted = false
