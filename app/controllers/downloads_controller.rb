class DownloadsController < ApplicationController

  before_filter :get_request, only: %i(get status manifest)

  def get
    if @request.ready?
      response.headers['X-Archive-Files'] = 'zip'
      #response.headers['X-Archive-Charset'] = 'UTF-8'
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
    json_string = request.body.read
    request = HttpRequestBridge.create_request(json_string)
    request.generate_manifest_and_links
    render json: HttpRequestBridge.request_received_ok_message(request).to_json, status: 201
  rescue JSON::ParserError
    'something'
  rescue Request::InvalidRoot
    'something'
  rescue Exception
    'something'
  end

  protected

  def get_request
    @request = Request.find_by(downloader_id: params[:id])
    if @request.blank?
      render status: :not_found, plain: 'Requested archive not found'
    end
  end


end