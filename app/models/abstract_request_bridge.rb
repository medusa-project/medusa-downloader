class AbstractRequestBridge < Object

  def self.create_request(unparsed_message)
    raise RuntimeError, 'Subclass responsibility'
  end

  def self.from_message(unparsed_message)
    parsed_message = JSON.parse(unparsed_message).with_indifferent_access
    ActiveRecord::Base.transaction do
      make_request(parsed_message)
    end
  end

  def self.make_request(json)
    check_parameters(json)
    id = generate_id
    Rails.logger.info("Creating request: #{id}")
    Request.create!(client_id: json[:client_id], return_queue: json[:return_queue],
                    root: json[:root], zip_name: zip_name(json, id), timeout: timeout(json), targets: json[:targets],
                    status: 'pending', downloader_id: id)
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
    SecureRandom.hex(24).tap do |id|
      Request.find_by(downloader_id: id).present? ? generate_id : id
    end
  end

  def self.check_parameters(json)
    raise Request::InvalidRoot unless MedusaDownloader::Application.storage_roots[json[:root]].present?
  end

  def self.request_received_ok_message(request)
    {
        status: 'ok',
        id: request.downloader_id,
        download_url: request.download_url,
        status_url: request.status_url
    }
  end

end