module WebrtcRails
  class Configuration
    attr_accessor :user_model_class, :fetch_user_by_token_method, :user_id

    def initialize
      @user_model_class = 'User'
      @fetch_user_by_token_method = :fetch_by_token
      @user_id = :id
    end
  end
end
