class Request < ActiveRecord::Base

  def self.from_message(amqp_message)
    json = JSON.parse(amqp_message)
  rescue JSON::ParserError
    Rails.logger.error "Unable to parse incoming message: #{amqp_message}"
    ErrorMailer.parsing_error(amqp_message).deliver_now
  end

end
