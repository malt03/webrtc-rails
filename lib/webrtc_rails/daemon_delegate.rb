module WebrtcRails
  class DaemonDelegate
    def onWebSocketConnected(user_identifier)

    end

    def onWebSocketDisconnected(user_identifier)

    end

    def onWantCall(sent_user_identifier, will_receive_user_identifier)
      true
    end

    def onWantSendUserMessage(sent_user_identifier, will_receive_user_identifier, event, message)
      true
    end
  end
end
