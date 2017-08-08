class AmqpRequestBridge < AbstractRequestBridge

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
  rescue Exception => e
    Rails.logger.error "Unknown error for incoming message: #{amqp_message}"
    Rails.logger "#{e}"
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
    AmqpConnector.instance.send_message(request.return_queue, request_received_ok_message(request))
  end

  def self.send_invalid_file_error(error, request)
    message = {
        action: 'error',
        id: request.downloader_id,
        error: "Missing or invalid file or directory: #{error.relative_path}"
    }
    AmqpConnector.instance.send_message(request.return_queue, message)
  end

  def self.send_request_completed(request)
    AmqpConnector.instance.send_message(request.return_queue, request_completed_message(request))
  end

  def self.check_parameters(json)
    super(json)
    raise Request::NoReturnQueue unless json[:return_queue].present?
    raise Request::NoClientId unless json[:client_id].present?
  end

  def self.request_received_ok_message(request)
    super(request).merge(client_id: request.client_id, action: 'request_received')
  end

  def self.request_completed_message(request)
    {
      action: 'request_completed',
      id: request.downloader_id,
      download_url: request.download_url,
      status_url: request.status_url,
      approximate_size: request.total_size
    }
  end

end