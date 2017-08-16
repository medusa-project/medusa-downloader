class DownloadsController < ApplicationController

  # include ActionController::Live
  # include ZipTricks::RailsStreaming
  include ActionController::Streaming 
  include Zipline

  before_filter :get_request, only: %i(get status manifest download)
  if Config.instance.auth_active?
    before_filter :authenticate, only: :create
  end
  skip_before_filter :verify_authenticity_token, only: :create
  
  def get
    if @request.ready?
      response.headers['X-Archive-Files'] = 'zip'
      send_file @request.manifest_path, disposition: :attachment, filename: "#{@request.zip_name}.zip"
    else
      render status: :not_found, plain: 'Manifest is not yet ready for this archive'
    end
  end

  # def download
  #   if @request.ready?
  #     manifest = File.open(@request.manifest_path)
  #     zip_tricks_stream do |zip|
  #       manifest.each_line do |line|
  #         line.chomp!
  #         dash, size, content_path, zip_path = line.split(' ', 4)
  #         content_path.gsub!(/^\/internal\//, '')
  #         zip.write_stored_file(zip_path) do |target|
  #           real_path = File.join(Config.instance.storage_path, content_path)
  #           Rails.logger.error("Content: #{real_path}, Zip: #{zip_path}, Size: #{size}")
  #           File.open(real_path, 'rb') do |source|
  #             IO.copy_stream(source, target)
  #           end
  #         end
  #       end
  #     end
  #   else
  #     render status: :not_found, plain: 'Manifest is not yet ready for this archive'
  #   end
  # end

  def download
    if @request.ready?
      manifest = File.open(@request.manifest_path)
      files = manifest.each_line.collect do |line|
        line.chomp!
        dash, size, content_path, zip_path = line.split(' ', 4)
        content_path.gsub!(/^\/internal\//, '')
        real_path = File.join(Config.instance.storage_path, content_path)
        [real_path, zip_path]
      end
      zipline(files, "#{@request.zip_name}.zip")
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
    #TODO require root
    if @request.blank? or (params[:root] != @request.root)
      render status: :not_found, plain: 'Requested archive not found'
    end
  end

  def authenticate
    authenticate_or_request_with_http_digest(Config.auth[:realm]) do |user|
      Config.auth[:users][user]
    end
  end

end