class @WebRTC
  myUserID: null

  onWebSocketConnected: ->
  onWebSocketReconnectingStarted: ->
  onWebSocketReConnected: ->
  onWebRTCConnected: ->
  onWebRTCReconnectingStarted: ->
  onWebRTCReconnected: ->
  onWebRTCHangedUp: ->

  constructor: (url, userToken, localOutput, remoteOutput) ->
    @localOutput = if localOutput? then (localOutput[0] || localOutput) else null
    @remoteOutput = remoteOutput[0] || remoteOutput
    @_startOutput(@localOutput)
    @_webSocketInitialize(url, userToken)
    @_addNetworkEventListener()

  connect: (remoteUserID) ->
    @_isCaller = true
    @_remoteUserID = remoteUserID
    if !@_peerStarted && @_localStream
      @_sendMessage(
        type: 'call'
        remoteUserID: @myUserID
      )
      @_sendOffer()
      @_peerStarted = true
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
    @_sendMessage(type: 'hangUp')
    @_hangedUp = true

  # private

  _hangedUp: true
  _localStream: null
  _peerConnection: null
  _peerStarted: false
  _mediaConstraints: 'mandatory':
    'OfferToReceiveAudio': true
    'OfferToReceiveVideo': true

  _webSocketInitialize: (url, userToken) ->
    @_url = url
    @_userToken = userToken
    @_webSocket = new WebSocket(url)
    @_webSocket.onopen = =>
      @_startHeartbeat()
      @_sendValue('setMyToken',
        token: String(userToken)
      )
      if @_webRTCRreconnecting
        @connect(@_remoteUserID)

    @_webSocket.onclose = (event) =>
      @onWebSocketReconnectingStarted()
      @_webSocketInitialize(url, userToken)

    @_webSocket.onmessage = (data) =>
      event = JSON.parse(data.data)
      switch event['type']
        when 'myUserID'
          @myUserID = event['myUserID']
          if @_webSocketConnected
            @onWebSocketReConnected()
          else
            @onWebSocketConnected()
            @_webSocketConnected = true
        when 'call'
          @_isCaller = false
          @_remoteUserID = event['remoteUserID']
        when 'hangUp'
          @_hangedUp = true
          @_sendMessage(type: 'hangUpAnswer')
          @_stop()
        when 'hangUpAnswer'
          @_stop()
        when 'offer'
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
        event: event
        value: value
      ))

  _sendMessage: (message) ->
    @_sendValue('sendMessage',
      userID: String(@_remoteUserID)
      message: message
    )

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
        when 'connected', 'completed'
          if @_hangedUp
            @onWebRTCConnected()
          else
            @onWebRTCReconnected()
          @_hangedUp = false

    peer.addStream(@_localStream)
    peer.addEventListener('addstream', onRemoteStreamAdded, false)
    peer.addEventListener('removestream', onRemoteStreamRemoved, false)
    peer

  _reconnectPeer: ->
    @_stop()
    if @_isCaller
      if @_webSocket.readyState == WebSocket.OPEN
        @connect()
      else
        @_webRTCRreconnecting = true

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

  _stop: ->
    @_peerConnection.removeStream(@_peerConnection.getRemoteStreams()[0])
    @_peerConnection.close()
    @_peerConnection = null
    @_peerStarted = false
