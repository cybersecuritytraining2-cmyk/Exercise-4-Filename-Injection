class ShareController < ApplicationController
  # VULNERABILITY 3: no auth required, token is a guessable Unix timestamp
  def download
    file = Store::FILES.values.find { |f| f[:share_token] == params[:token] }
    return render json: { error: "Not found" }, status: :not_found unless file

    send_data File.binread(file[:path]),
              filename:    file[:filename],
              type:        "application/octet-stream",
              disposition: "attachment"
  end
end
