class @WebRTC
  onConnected: ->
  onHangedUp: ->
  onReconnectingStarted: ->

  constructor: (userIdentifier, @localOutput, @remoteOutput) ->
    @localOutput = @localOutput[0] || @localOutput
    @remoteOutput = @remoteOutput[0] || @remoteOutput
    @_startOutput(@localOutput.tagName.toUpperCase() == 'VIDEO')
    @_webSocketInitialize(userIdentifier)

  connect: (myUserID, remoteUserID) ->
    @remoteUserID = remoteUserID
    if !@_peerStarted && @_localStream
      @_sendMessage(
        type: 'call'
        remoteUserID: myUserID
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
    @onHangedUp()
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

  _webSocketInitialize: (userIdentifier) ->
    @_webSocket = new WebSocket('ws://' + location.host + '/websocket')
    @_webSocket.onopen = =>
      @_heartbeat()
      @_sendValue('setMyIdentifier',
        identifier: String(userIdentifier)
      )

    @_webSocket.onmessage = (data) =>
      event = JSON.parse(data.data)
      switch event['type']
        when 'call'
          @remoteUserID = event['remoteUserID']
        when 'hangUp'
          @onHangedUp()
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
        when 'user disconnected'
          if @_peerStarted
            @_stop()

  _heartbeat: ->
    @_sendValue('heartbeat', null)
    window.setTimeout(
      =>
        @_heartbeat()
      5000
    )

  _sendValue: (event, value) ->
    @_webSocket.send(JSON.stringify(
      event: event
      value: value
    ))

  _sendMessage: (message) ->
    @_sendValue('sendMessage',
      identifier: String(@remoteUserID)
      message: message
    )

  _startOutput: (video) ->
    navigator.webkitGetUserMedia(
      video: video
      audio: true
      (stream) =>
        @_localStream = stream
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
          console.log(@_wsRails.stale)
          @onReconnectingStarted()
        when 'connected', 'completed'
          if @_hangedUp
            @onConnected()
          @_hangedUp = false

    peer.addStream(@_localStream)
    peer.addEventListener('addstream', onRemoteStreamAdded, false)
    peer.addEventListener('removestream', onRemoteStreamRemoved, false)
    peer

  _sendOffer: ->
    @_peerConnection = @_prepareNewConnection()
    @_peerConnection.createOffer(
      (sessionDescription) =>
        @_peerConnection.setLocalDescription(sessionDescription)
        @_sendSDP(sessionDescription)
      ->
        console.log 'Create Offer failed'
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
