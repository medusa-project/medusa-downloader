require 'securerandom'
require 'fileutils'
class Request < ActiveRecord::Base

  has_one :manifest_creation, dependent: :destroy

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

  def download_url
    "#{Config.nginx_url}/#{downloader_id}/download"
  end

  def status_url
    "#{Config.nginx_url}/#{downloader_id}/status"
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

  def generate_manifest_and_links
    FileUtils.mkdir_p(File.dirname(manifest_path))
    File.open(manifest_path, 'wb') do |f|
      #TODO use targets to create actual manifest and links
      f.puts 'fake manifest'
    end
    self.status = 'ready'
    self.save!
  end

end
