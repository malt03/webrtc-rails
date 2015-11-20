class @WebRTC
  @DISCONNECTED: 0
  @TIMEOUT: 1
  @CALLING: 2

  myUserID: null

  onWebSocketConnected: ->
  onWebSocketReconnectingStarted: ->
  onWebSocketReconnected: ->
  onWebRTCConnected: ->
  onWebRTCReconnectingStarted: ->
  onWebRTCReconnected: ->
  onWebRTCHangedUp: ->
  onWebRTCConnectFailed: (reason) ->

  constructor: (url, userToken, localOutput, remoteOutput) ->
    @localOutput = if localOutput? then (localOutput[0] || localOutput) else null
    @remoteOutput = remoteOutput[0] || remoteOutput
    @_startOutput(@localOutput)
    @_webSocketInitialize(url, userToken)
    @_addNetworkEventListener()

  connect: (remoteUserID) ->
    if @_webRTCReconnecting && @_hangedUp
      @_webRTCReconnecting = false
      return

    @_isCaller = true
    @_remoteUserID = remoteUserID
    if !@_peerStarted && @_localStream
      @_sendMessage(
        type: 'call'
        remoteUserID: @myUserID
        reconnect: @_webRTCReconnecting
      )
      @_callAnswerReceived = false
      window.setTimeout(
        =>
          unless @_callAnswerReceived
            if @_webRTCReconnecting
              @connect(remoteUserID)
            else
              @onWebRTCConnectFailed(WebRTC.TIMEOUT)
        5000
      )
    else
      alert 'Local stream not running yet - try again.'

  enableVideo: ->
    @setVideoEnabled(true)

  disableVideo: ->
    @setVideoEnabled(false)

  setVideoEnabled: (enabled) ->
    for track in @_localStream.getVideoTracks()
      track.enabled = enabled

  hangUp: ->
    @_hangUp()
    @_sendMessage(type: 'hangUp')

  # private

  _hangedUp: true
  _localStream: null
  _peerConnection: null
  _peerStarted: false
  _mediaConstraints: 'mandatory':
    'OfferToReceiveAudio': true
    'OfferToReceiveVideo': true

  _webSocketInitialize: (url, userToken) ->
    @_userToken = userToken
    @_webSocket = new WebSocket(url)
    @_webSocket.onopen = =>
      @_startHeartbeat()
      @_sendValue('setMyToken')
      if @_wantWebRTCReconnecting
        @_wantWebRTCReconnecting = false
        @connect(@_remoteUserID)

    @_webSocket.onclose = (event) =>
      unless @_isWebSocketReconnectingStarted
        @_isWebSocketReconnectingStarted = true
        @onWebSocketReconnectingStarted()
      @_webSocketInitialize(url, userToken)

    @_webSocket.onmessage = (data) =>
      event = JSON.parse(data.data)
      eventType = event['type']
      if eventType != 'myUserID' && eventType != 'call' && eventType != 'webSocketReconnected'
        if @_remoteUserID != event['remoteUserID']
          return
        
      switch eventType
        when 'myUserID'
          @myUserID = event['myUserID']
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
          if @_hangedUp || @_remoteUserID != event['remoteUserID']
            @_sendMessageToOther(type: 'hangUp', event['remoteUserID'])
        when 'callFailed'
          @_callAnswerReceived = true
          @onWebRTCConnectFailed(event['reason'] || WebRTC.UNKNOWN)
        when 'call'
          if @_peerStarted
            message =
              type: 'callFailed'
              reason: WebRTC.CALLING
            @_sendMessageToOther(message, event['remoteUserID'])
          else if event['reconnect'] && @_hangedUp
            @_sendMessage(type: 'hangUp')
          else
            @_isCaller = false
            @_remoteUserID = event['remoteUserID']
            @_sendOffer()
            @_peerStarted = true
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

  _sendMessageToOther: (message, userID) ->
    @_sendValue('sendMessage',
      userID: String(userID)
      message: message
    )
    
  _sendMessage: (message) ->
    @_sendMessageToOther(message, @_remoteUserID)

  _startOutput: (localOutput) ->
    isVideo = (@localOutput? && @localOutput.tagName.toUpperCase() == 'VIDEO')
    navigator.webkitGetUserMedia(
      video: isVideo
      audio: true
      (stream) =>
        @_localStream = stream
        if @localOutput?
          @localOutput.src = window.URL.createObjectURL(@_localStream)
          @localOutput.play()
          @localOutput.volume = 0
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
    candidate = new RTCIceCandidate(
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
    pcConfig = 'iceServers': [ "url": "stun:stun.l.google.com:19302" ]
    peer = null

    onRemoteStreamAdded = (event) =>
      @remoteOutput.src = window.URL.createObjectURL(event.stream)

    onRemoteStreamRemoved = (event) =>
      @remoteOutput.src = ''

    try
      peer = new webkitRTCPeerConnection(pcConfig)
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
        @connect(@_remoteUserID)
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
    @_peerConnection.setRemoteDescription(new RTCSessionDescription(event))

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
    @_peerConnection.setRemoteDescription(new RTCSessionDescription(event))

  _hangUp: ->
    @_stop()
    @_hangedUp = true
    @onWebRTCHangedUp()

  _stop: ->
    if @_peerConnection?
      @_peerConnection.removeStream(@_peerConnection.getRemoteStreams()[0])
      @_peerConnection.close()
      @_peerConnection = null
    @_peerStarted = false
