module Api
  class FilesController < ApplicationController
    before_action :authenticate!

    def index
      files = Store::FILES.values.select { |f| f[:owner_email] == current_user[:email] }
      render json: files.map { |f| f.reject { |k, _| k == :path } }
    end

    def create
      file_param = params[:file]
      return render json: { error: "No file provided" }, status: :unprocessable_entity unless file_param

      id = Store.next_id
      # VULNERABILITY 3: share token is a Unix timestamp — predictable by timing the upload
      share_token = Time.now.to_i.to_s
      safe_name   = File.basename(file_param.original_filename).gsub(/[^a-zA-Z0-9._-]/, "_")
      path        = Rails.root.join("storage", "#{id}_#{safe_name}").to_s

      FileUtils.cp(file_param.tempfile.path, path)

      record = {
        id:           id,
        filename:     file_param.original_filename,
        path:         path,
        owner_email:  current_user[:email],
        share_token:  share_token,
        size:         file_param.size,
        uploaded_at:  Time.now.iso8601
      }
      Store::FILES[id] = record

      render json: record.reject { |k, _| k == :path }, status: :created
    end

    # VULNERABILITY 2: sequential integer IDs, no ownership verification
    def show
      file = Store::FILES[params[:id].to_i]
      return render json: { error: "Not found" }, status: :not_found unless file

      # Missing ownership check: any authenticated user can download any file by guessing the ID
      send_data File.binread(file[:path]),
                filename:    file[:filename],
                type:        "application/octet-stream",
                disposition: "attachment"
    end

    # VULNERABILITY 1: no ownership verification — any authenticated user can delete any file
    def destroy
      file = Store::FILES[params[:id].to_i]
      return render json: { error: "Not found" }, status: :not_found unless file

      # Missing ownership check: file[:owner_email] != current_user[:email]
      FileUtils.rm_f(file[:path])
      Store::FILES.delete(params[:id].to_i)
      render json: { message: "File deleted" }
    end
  end
end
