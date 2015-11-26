module WebrtcRails
  class Configuration
    attr_accessor :user_model_class, :fetch_user_by_token_method, :user_id, :daemon_delegate

    def initialize
      @user_model_class = 'User'
      @fetch_user_by_token_method = :fetch_by_token
      @user_id = :id
      @daemon_delegate = 'WebrtcRails::DaemonDelegate'
    end
  end
end
