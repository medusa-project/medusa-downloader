require 'securerandom'
require 'fileutils'
class Request < ActiveRecord::Base

  attr_accessor :file_list, :storage_root

  has_one :manifest_creation, dependent: :destroy

  STATUSES = %w(pending creating_manifest ready missing_or_invalid_targets)

  validates :status, inclusion: STATUSES, allow_blank: false

  def self.from_message(amqp_message)
    parsed_message = JSON.parse(amqp_message).with_indifferent_access
    ActiveRecord::Base.transaction do
      create_request(parsed_message, generate_id).tap do |request|
        ManifestCreation.create_for(request)
        request.send_request_received_ok
      end
    end
  rescue JSON::ParserError
    Rails.logger.error "Unable to parse incoming message: #{amqp_message}"
    ErrorMailer.parsing_error(amqp_message).deliver_now
  rescue Request::NoReturnQueue
    Rails.logger.error "No return queue for incoming message: #{amqp_message}"
  rescue Request::NoClientId
    Rails.logger.error "No client id for incoming message: #{amqp_message}"
    send_no_client_id_error(parsed_message)
  rescue Request::InvalidRoot
    Rails.logger.error "Invalid root for incoming message: #{amqp_message}"
    send_invalid_root_error(parsed_message)
  rescue Exception
    Rails.logger.error "Unknown error for incoming message: #{amqp_message}"
  end

  def self.check_parameters(json_request)
    true
  end

  def self.zip_name(json, default)
    json[:zip_name] || default
  end

  def self.timeout(json)
    [[json[:timeout], 1].compact.max, default_timeout].min
  end

  def self.default_timeout
    14
  end

  def self.generate_id
    SecureRandom.hex(4).tap do |id|
      find_by(downloader_id: id).present? ? generate_id : id
    end
  end

  def self.create_request(json, id)
    check_parameters(json)
    Request.create!(client_id: json[:client_id], return_queue: json[:return_queue],
                    root: json[:root], zip_name: zip_name(json, id), timeout: timeout(json), targets: json[:targets],
                    status: 'pending', downloader_id: id)
  end

  def self.check_parameters(json)
    raise Request::NoReturnQueue unless json[:return_queue].present?
    raise Request::NoClientId unless json[:client_id].present?
    raise Request::InvalidRoot unless StorageRoot.find(json[:root])
  end

  def send_request_received_ok
    message = {
        action: 'request_received',
        client_id: client_id,
        status: 'ok',
        id: downloader_id,
        download_url: download_url,
        status_url: status_url
    }
    AmqpConnector.instance.send_message(self.return_queue, message)
  end

  def self.send_invalid_root_error(parsed_message)
    message = {
        action: 'request_received',
        client_id: parsed_message[:client_id],
        status: 'error',
        error: "Invalid root: #{parsed_message[:root]}"
    }
    AmqpConnector.instance.send_message(parsed_message[:return_queue], message)
  end

  def self.send_no_client_id_error(parsed_message)
    message = {
        action: 'request_received',
        client_id: parsed_message[:client_id],
        status: 'error',
        error: "No client id: #{parsed_message.to_json}"
    }
    AmqpConnector.instance.send_message(parsed_message[:return_queue], message)
  end

  def send_invalid_file_error(error)
    message = {
        action: 'error',
        id: downloader_id,
        error: "Missing or invalid file or directory: #{error.relative_path}"
    }
    AmqpConnector.instance.send_message(return_queue, message)
  end

  def download_url
    "#{Config.nginx_url}/#{downloader_id}/get"
  end

  def status_url
    "#{Config.nginx_url}/#{downloader_id}/status"
  end

  def manifest_url
    "#{Config.nginx_url}/#{downloader_id}/manifest"
  end

  def has_manifest?
    File.exist?(manifest_path)
  end

  def storage_path
    File.join(Config.instance.storage_path, self.downloader_id)
  end

  def manifest_path
    File.join(storage_path, 'manifest.txt')
  end

  def data_path
    File.join(storage_path, 'data')
  end

  def generate_manifest_and_links
    self.status = 'creating_manifest'
    FileUtils.mkdir_p(File.dirname(manifest_path))
    FileUtils.mkdir_p(data_path)
    generate_file_list
    File.open(manifest_path, 'wb') do |f|
      self.file_list.each.with_index do |spec, i|
        path, zip_path, size = spec
        symlink_path = File.join(data_path, i.to_s)
        FileUtils.symlink(path, symlink_path)
        f.write "- #{size} #{relative_path_to(symlink_path)} #{zip_name}/#{zip_path}\r\n"
      end
    end
    self.status = 'ready'
    self.save!
  rescue InvalidFileError => e
    send_invalid_file_error(e)
    File.delete(manifest_path) if File.exist?(manifest_path)
    self.status = 'missing_or_invalid_targets'
    self.save!
  end

  #create from the targets a list of files to be included and also their destinations in the zip file and sizes
  #throw an error if a file/directory does not exist, if it is outside of the root, if the target type is invalid,
  #etc.
  def generate_file_list
    self.storage_root = StorageRoot.find(self.root)
    self.file_list = Array.new
    self.targets.each do |target|
      add_target(target)
    end
  end

  def add_target(target)
    case target['type']
      when 'file'
        add_file(target)
      when 'directory'
        add_directory(target)
      else
        raise InvalidTargetTypeError.new(target)
    end
  end

  def add_file(target)
    file_path = self.storage_root.path_to(target['path'])
    raise InvalidFileError(self.root, target['path']) unless File.file?(file_path)
    zip_file_path = target[:zip_path] || File.basename(file_path)
    size = File.size(file_path)
    self.file_list << [file_path, zip_file_path, size]
  end

  def add_directory(target)
    directory_path = self.storage_root.path_to(target['path'])
    raise InvalidFileError(self.root, target['path']) unless Dir.exist?(directory_path)
    zip_path = target['zip_path'] || target['path']
    recurse = target['recursive'] == true
    dir = Pathname.new(directory_path)
    dir.find.each do |descendant|
      next if descendant == dir
      if descendant.file?
        zip_file_path = File.join(zip_path, descendant.to_s.sub(/^#{dir.to_s}\//, ''))
        size = descendant.size
        self.file_list << [descendant.to_s, zip_file_path, size]
      else
        Find.prune if recurse.blank? and descendant.directory?
      end
    end
  end

  def relative_path_to(absolute_path)
    absolute_path.sub(/^#{Config.instance.storage_path}/, '')
  end

  STATUSES.each do |status|
    define_method :"#{status}?" do
      self.status == status
    end
  end

end
