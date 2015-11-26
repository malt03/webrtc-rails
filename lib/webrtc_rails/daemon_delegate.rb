module WebrtcRails
  class DaemonDelegate
    def onWebSocketConnected(user_id)

    end

    def onWebSocketDisconnected(user_id)

    end

    def onWantCall(sent_user_id, will_receive_user_id)
      true
    end

    def onWantSendUserMessage(sent_user_id, will_receive_user_id, event, message)
      true
    end
  end
end
