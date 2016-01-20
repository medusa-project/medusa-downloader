class HttpRequestBridge < AbstractRequestBridge

  def self.create_request(unparsed_message)
    from_message(unparsed_message)
  end

end