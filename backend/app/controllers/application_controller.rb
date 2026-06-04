class ApplicationController < ActionController::API
  def authenticate!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    @current_user = Store::USERS.values.find { |u| u[:token] == token }
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end
end
