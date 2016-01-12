class DownloadsController < ApplicationController

  before_filter :get_request

  def get

  end

  def status

  end

  def manifest

  end

  protected

  def get_request
    @request = Request.find_by(downloader_id: params[:id])
    if @request.blank?
      render status: :not_found, plain: 'Requested archive not found'
    end
  end


end