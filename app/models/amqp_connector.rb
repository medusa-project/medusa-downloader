#Represent AMQP connection and provide convenience methods.
#The amqp config section can contain any option
#appropriate for Bunny.new.
require 'singleton'
require 'set'

class AmqpConnector < Object
  include Singleton

  attr_accessor :connection, :known_queues

  def initialize
    self.reinitialize
  end

  def reinitialize
    config = Settings.amqp
    # config.merge!(recover_from_connection_close: true)
    self.known_queues = Set.new
    self.connection.close if self.connection
    self.connection = Bunny.new(config.to_h)
    self.connection.start
  end

  def clear_queues(*queue_names)
    queue_names.each do |queue_name|
      continue = true
      while continue
        with_message(queue_name) do |message|
          continue = message
          puts "#{self.class} clearing: #{message} from: #{queue_name}" if message
        end
      end
    end
  end

  def with_channel
    channel = connection.create_channel
    yield channel
  ensure
    channel.close
  end

  def with_queue(queue_name)
    with_channel do |channel|
      queue = channel.queue(queue_name, durable: true)
      yield queue
    end
  end

  def ensure_queue(queue_name)
    unless self.known_queues.include?(queue_name)
      with_queue(queue_name) do |queue|
        #no-op, just ensuring queue exists
      end
      self.known_queues << queue_name
    end
  end

  def with_message(queue_name)
    with_queue(queue_name) do |queue|
      delivery_info, properties, raw_payload = queue.pop
      yield raw_payload
    end
  end

  def with_parsed_message(queue_name)
    with_message(queue_name) do |message|
      json_message = message ? JSON.parse(message) : nil
      yield json_message
    end
  end

  def with_exchange
    with_channel do |channel|
      exchange = channel.default_exchange
      yield exchange
    end
  end

  def send_message(queue_name, message)
    ensure_queue(queue_name)
    with_exchange do |exchange|
      message = message.to_json if message.is_a?(Hash)
      exchange.publish(message, routing_key: queue_name, persistent: true)
    end
  end

end