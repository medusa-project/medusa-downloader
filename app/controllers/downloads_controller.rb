class DownloadsController < ApplicationController

  before_filter :get_request

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

  protected

  def get_request
    @request = Request.find_by(downloader_id: params[:id])
    if @request.blank?
      render status: :not_found, plain: 'Requested archive not found'
    end
  end


end