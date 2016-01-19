class AmqpRequestFactory < Object

  def self.create_request(amqp_message)
    from_message(amqp_message).tap do |request|
      ManifestCreation.create_for(request)
      send_request_received_ok(request)
    end
  rescue JSON::ParserError
    Rails.logger.error "Unable to parse incoming message: #{amqp_message}"
    ErrorMailer.parsing_error(amqp_message).deliver_now
  rescue Request::NoReturnQueue
    Rails.logger.error "No return queue for incoming message: #{amqp_message}"
  rescue Request::NoClientId
    Rails.logger.error "No client id for incoming message: #{amqp_message}"
    send_no_client_id_error(amqp_message)
  rescue Request::InvalidRoot
    Rails.logger.error "Invalid root for incoming message: #{amqp_message}"
    send_invalid_root_error(amqp_message)
  rescue Exception
    Rails.logger.error "Unknown error for incoming message: #{amqp_message}"
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
    SecureRandom.hex(4).tap do |id|
      Request.find_by(downloader_id: id).present? ? generate_id : id
    end
  end

  def self.check_parameters(json)
    raise Request::NoReturnQueue unless json[:return_queue].present?
    raise Request::NoClientId unless json[:client_id].present?
    raise Request::InvalidRoot unless StorageRoot.find(json[:root])
  end

  def self.send_invalid_root_error(amqp_message)
    parsed_message = JSON.parse(amqp_message).with_indifferent_access
    message = {
        action: 'request_received',
        client_id: parsed_message[:client_id],
        status: 'error',
        error: "Invalid root: #{parsed_message[:root]}"
    }
    AmqpConnector.instance.send_message(parsed_message[:return_queue], message)
  end

  def self.send_no_client_id_error(amqp_message)
    parsed_message = JSON.parse(amqp_message).with_indifferent_access
    message = {
        action: 'request_received',
        client_id: parsed_message[:client_id],
        status: 'error',
        error: "No client id: #{parsed_message.to_json}"
    }
    AmqpConnector.instance.send_message(parsed_message[:return_queue], message)
  end

  def self.send_request_received_ok(request)
    message = {
        action: 'request_received',
        client_id: request.client_id,
        status: 'ok',
        id: request.downloader_id,
        download_url: request.download_url,
        status_url: request.status_url
    }
    AmqpConnector.instance.send_message(request.return_queue, message)
  end

end