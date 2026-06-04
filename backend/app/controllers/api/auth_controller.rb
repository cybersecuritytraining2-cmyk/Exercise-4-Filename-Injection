module Api
  class AuthController < ApplicationController
    def register
      email = params[:email].to_s.strip.downcase
      name  = params[:name].to_s.strip
      password = params[:password].to_s

      return render json: { error: "Email, name and password are required" }, status: :unprocessable_entity if email.empty? || name.empty? || password.empty?
      return render json: { error: "Email already registered" }, status: :unprocessable_entity if Store::USERS[email]

      Store::USERS[email] = { email: email, password: password, name: name, token: nil }
      render json: { message: "Registered successfully" }, status: :created
    end

    def login
      email    = params[:email].to_s.strip.downcase
      password = params[:password].to_s
      user     = Store::USERS[email]

      return render json: { error: "Invalid credentials" }, status: :unauthorized unless user && user[:password] == password

      token = SecureRandom.hex(32)
      user[:token] = token
      render json: { token: token, name: user[:name], email: user[:email] }
    end
  end
end
