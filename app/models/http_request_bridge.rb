class HttpRequestBridge < AbstractRequestBridge

  def self.create_request(unparsed_message)
    from_message(unparsed_message)
  end

  def self.request_received_ok_message(request)
    super(request).merge(approximate_size: request.total_size)
  end

end