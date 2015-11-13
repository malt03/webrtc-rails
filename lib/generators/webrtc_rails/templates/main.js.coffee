class @WebRTC
  onConnected: ->
  onHangedUp: ->
  onReconnectingStarted: ->

  constructor: (userID, @localOutput, @remoteOutput) ->
    @localOutput = @localOutput[0] || @localOutput
    @remoteOutput = @remoteOutput[0] || @remoteOutput
    @_startOutput(@localOutput.tagName.toUpperCase() == 'VIDEO')
    @wsRails = new WebSocketRails(location.host + "/websocket?webrtc=true&user_identifier=" + userID)
    @wsRails.bind("webrtc"
      (data) =>
        event = JSON.parse(data)
        switch event['type']
          when 'call'
            @remoteUserID = event['remoteUserID']
          when 'hangUp'
            @onHangedUp()
            @_hangedUp = true
            @_sendMessage(JSON.stringify(type: 'hangUpAnswer'))
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
    )

  connect: (myUserID, remoteUserID) ->
    @remoteUserID = remoteUserID
    if !@_peerStarted && @_localStream
      @_sendMessage(JSON.stringify(
        type: 'call'
        remoteUserID: myUserID
      ))
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
    @_sendMessage(JSON.stringify(type: 'hangUp'))
    @_hangedUp = true

  # private

  _hangedUp: true
  _localStream: null
  _peerConnection: null
  _peerStarted: false
  _mediaConstraints: 'mandatory':
    'OfferToReceiveAudio': true
    'OfferToReceiveVideo': true

  _sendMessage: (message) ->
    $.ajax(
      type: 'POST'
      url: '/webrtc'
      data:
        user_id: @remoteUserID
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
    text = JSON.stringify(sdp)
    @_sendMessage(text)

  _sendCandidate: (candidate) ->
    text = JSON.stringify(candidate)
    @_sendMessage(text)

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
