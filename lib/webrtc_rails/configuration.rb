module WebrtcRails
  class Configuration
    attr_accessor :user_model_class, :fetch_user_by_token_method, :user_identifier, :daemon_delegate, :output_dir

    def initialize
      @user_model_class = 'User'
      @fetch_user_by_token_method = :fetch_by_token
      @user_identifier = :id
      @daemon_delegate = 'WebrtcRails::DaemonDelegate'
      @output_dir = File.join(Rails.root, %w/log webrtc_rails/)
    end
  end
end
