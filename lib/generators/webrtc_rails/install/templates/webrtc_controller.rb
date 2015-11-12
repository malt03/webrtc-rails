class WebrtcController < ApplicationController
  def send_message
    WebsocketRails.users[params[:user_id]].send_message 'message', params[:message]
  end
end
