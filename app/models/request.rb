require 'securerandom'
class Request < ActiveRecord::Base

  has_one :manifest_creation, dependent: :destroy

  def self.from_message(amqp_message)
    json = JSON.parse(amqp_message).with_indifferent_access
    id = generate_id
    ActiveRecord::Base.transaction do
      create_request(json, id).tap do |request|
        ManifestCreation.create_for(request)
        request.send_request_received
      end
    end
  rescue JSON::ParserError
    Rails.logger.error "Unable to parse incoming message: #{amqp_message}"
    ErrorMailer.parsing_error(amqp_message).deliver_now
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

  def send_request_received
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

  def download_url
    "#{Config.nginx_url}/#{downloader_id}/download"
  end

  def status_url
    "#{Config.nginx_url}/#{downloader_id}/status"
  end

end
