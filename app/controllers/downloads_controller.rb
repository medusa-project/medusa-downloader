require 'open3'
class DownloadsController < ApplicationController

  include ActionController::Live
  # include ZipTricks::RailsStreaming
  # include ActionController::Streaming
  #include Zipline

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

  # def download
  #   if @request.ready?
  #     manifest = File.open(@request.manifest_path)
  #     file_struct = Struct.new(:file)
  #     files = manifest.each_line.collect do |line|
  #       line.chomp!
  #       dash, size, content_path, zip_path = line.split(' ', 4)
  #       content_path.gsub!(/^\/internal\//, '')
  #       real_path = File.join(Config.instance.storage_path, content_path)
  #       [file_struct.new(real_path), zip_path]
  #     end
  #     zipline(files, "#{@request.zip_name}.zip")
  #   else
  #     render status: :not_found, plain: 'Manifest is not yet ready for this archive'
  #   end
  # end

  def download
    if @request.ready?
      begin
        response.headers['Content-Type'] = 'application/zip'
        response.headers['Content-Disposition'] = %Q(attachment; filename="#{@request.zip_name || @request.downloader_id}.zip")
        t = Thread.new do
          Open3.popen2('java', '-jar', File.join(Rails.root, 'jars', 'clojure-zipper.jar'), @request.manifest_path, Config.instance.storage_path) do |stdin, stdout, wait_thr|
            #buffer = ''
            buffer_size = 1024
            begin
              while true
                buffer = stdout.readpartial(buffer_size)
                response.stream.write(buffer) if buffer.length > 0
              end
            rescue EOFError
              Rails.logger.error "Done reading pipe"
            end
            # while true
            #   result = stdout.read(buffer_size, buffer)
            #   response.stream.write buffer unless result.nil?
            #   break if result.nil? or result.length == 0
            # end
            # while !stdout.eof?
            #   stdout.readpartial(buffer_size, buffer)
            #   unless buffer.nil? or buffer.length.zero?
            #     Rails.logger.error "Read #{buffer}"
            #     response.stream.write(buffer)
            #   end
            # end
            Rails.logger.error wait_thr.value.inspect
          end
        end
        t.join
      ensure
        response.stream.close
      end
    else
      render status: :not_found, plain: 'Manifest is not yet ready for this archive'
    end
  end

  # def download
  #   if @request.ready?
  #     begin
  #       #TODO: make fifo - for now just use one for testing
  #       pipe_path = File.join(Rails.root, 'pipe')
  #       zip_thread = Thread.new do
  #         begin
  #           pipe_output_stream = FileOutputStream.new(pipe_path)
  #           zip_stream = ZipOutputStream.new(pipe_output_stream)
  #           zip_stream.set_level(0)
  #           manifest = File.open(@request.manifest_path)
  #           manifest.each_line do |line|
  #             line.chomp!
  #             dash, file_size, content_path, zip_path = line.split(' ', 4)
  #             content_path.gsub!(/^\/internal\//, '')
  #             real_path = File.join(DownloaderConfig.instance.storage_path, content_path)
  #             zip_entry = ZipEntry.new(zip_path)
  #             Rails.logger.error(zip_path)
  #             zip_stream.put_next_entry(zip_entry)
  #             input_stream = FileInputStream.new(real_path)
  #             IOUtils.copy_large(input_stream, zip_stream)
  #             Rails.logger.error("DONE: " + zip_path)
  #           end
  #         ensure
  #           pipe_output_stream.close
  #           zip_stream.close
  #         end
  #       end
  #       output_thread = Thread.new do
  #         #f = File.open(pipe_path, File::RDONLY | File::BINARY | File::NONBLOCK)
  #         File.open(pipe_path, 'rb') do |f|
  #           response.headers['Content-Type'] = 'application/zip'
  #           response.headers['Content-Disposition'] = %Q(attachment; filename="#{@request.zip_name || @request.downloader_id}.zip")
  #           size = 1024
  #           buffer = ''
  #           total_bytes = 0
  #           while !f.eof?
  #             f.readpartial(size, buffer)
  #             unless bytes.nil? or bytes.length.zero?
  #               response.stream.write(bytes)
  #               total_bytes += bytes.length
  #               Rails.logger.error "READ #{total_bytes} bytes"
  #             end
  #           end
  #         end
  #       end
  #       zip_thread.join
  #       output_thread.join
  #     ensure
  #       response.stream.close
  #     end
  #   else
  #     render status: :not_found, plain: 'Manifest is not yet ready for this archive'
  #   end``

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