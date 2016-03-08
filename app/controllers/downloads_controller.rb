class DownloadsController < ApplicationController

  before_filter :get_request, only: %i(get status manifest)
  before_filter :authenticate, only: :create
  skip_before_filter :verify_authenticity_token, only: :create
  
  def get
    if @request.ready?
      response.headers['X-Archive-Files'] = 'zip'
      send_file @request.manifest_path, disposition: :attachment, filename: "#{@request.zip_name}.zip"
    else
      render status: :not_found, plain: 'Manifest is not yet ready for this archive'
    end
  end

  def status

  end

  def manifest
    if @request.ready?
      send_file @request.manifest_path, disposition: :inline, type: 'text/plain'
    else
      render status: :not_found, plain: 'Manifest is not yet ready for this archive'
    end
  end

  def create
    Request.transaction do
      json_string = request.body.read
      req = HttpRequestBridge.create_request(json_string)
      req.generate_manifest_and_links
      render json: HttpRequestBridge.request_received_ok_message(req).to_json, status: 201
    end
  rescue JSON::ParserError
    render json: {error: 'Unable to parse request body'}.to_json, status: 400
  rescue Request::InvalidRoot
    render json: {error: 'Invalid root'}.to_json, status: 400
  rescue InvalidFileError
    render json: {error: 'Invalid or missing file'}.to_json, status: 400
  rescue Exception
    render json: {error: 'Unknown error'}.to_json, status: 500
  end

  protected

  def get_request
    @request = Request.find_by(downloader_id: params[:id])
    if @request.blank?
      render status: :not_found, plain: 'Requested archive not found'
    end
  end

  def authenticate
    authenticate_or_request_with_http_digest(Config.auth[:realm]) do |user|
      Config.auth[:users][user]
    end
  end

end