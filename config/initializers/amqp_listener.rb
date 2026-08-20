if Rails.env.test?
  amqp_settings_path = File.join(Rails.root, 'config', 'amqp_test.yml')
else
  amqp_settings_path = File.join(Rails.root, 'config', 'amqp.yml')
end

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      begin
        amqp_settings = YAML.load(ERB.new(File.read(amqp_settings_path)).result, aliases: true)[Rails.env]
        Rails.logger.warn 'Attempting to start AMQP listener'
        AmqpListenerState.mark_starting!
        Rails.logger.warn 'Initializing connection'
        connection = Bunny.new(amqp_settings)
        Rails.logger.warn 'Starting connection'
        connection.start
        Kernel.at_exit do
          Rails.logger.warn 'Closing connection'
          AmqpListenerState.mark_stopped!
          connection.close rescue nil
        end
        Rails.logger.warn 'Starting AMQP listener'
        channel = connection.create_channel
        queue = channel.queue(DOWNLOADER_CONFIG[:incoming_queue], durable: true)
        AmqpListenerState.mark_running!(connection: connection)
        queue.subscribe do |delivery_info, properties, payload|
          begin
            AmqpRequestBridge.create_request(payload)
            Rails.logger.warn "Created request from #{payload}"
          rescue Exception => e
            Rails.logger.error "Failed to create request from #{payload}: #{e}"
          end
        end
      rescue Bunny::TCPConnectionFailed => e
        AmqpListenerState.mark_error!(e)
        Rails.logger.error "TCP connection error starting AMQP listener: #{e}"
      rescue Exception => e
        AmqpListenerState.mark_error!(e)
        Rails.logger.error "Unknown error starting AMQP listener: #{e}"
      end
    end
  end

  PhusionPassenger.on_event(:stopping_worker_process) do
    # Remove process status file on clean shutdown
    Rails.logger.warn 'Closing connection'
    AmqpListenerState.mark_stopped!
  end
end

# def start_amqp_listener(retries = 5, delay = 1)
#   begin
#     amqp_settings_path = File.join(Rails.root, 'config', 'amqp.yml')
#     amqp_settings = YAML.load(ERB.new(File.read(amqp_settings_path)).result)[Rails.env]
#     Rails.logger.warn 'Attempting to start AMQP listener'
#     AmqpListenerState.mark_starting!
#     Rails.logger.warn 'Initializing connection'
#     connection = Bunny.new(amqp_settings)
#     Rails.logger.warn 'Starting connection'
#     connection.start
  
#     Kernel.at_exit do
#       AmqpListenerState.mark_stopped!
#       connection.close rescue nil
#     end
#     Rails.logger.warn 'Starting AMQP listener'
#     channel = connection.create_channel
#     queue = channel.queue(DOWNLOADER_CONFIG[:incoming_queue], durable: true)
#     AmqpListenerState.mark_running!(connection: connection, queue_name: DOWNLOADER_CONFIG[:incoming_queue])
#     queue.subscribe do |delivery_info, properties, payload|
#       begin
#         AmqpRequestBridge.create_request(payload)
#         Rails.logger.warn "Created request from #{payload}"
#       rescue Exception => e
#         Rails.logger.error "Failed to create request from #{payload}: #{e}"
#       end
#     end
#   rescue Bunny::TCPConnectionFailed => e
#     if retries > 0
#       connection.close rescue nil
#       Rails.logger.error "Failed to connect to AMQP server: #{e}. Retrying in #{delay} seconds..."
#       sleep(delay)
#       start_amqp_listener(retries - 1, delay * 2)
#     else
#       AmqpListenerState.mark_error!(e)
#       Rails.logger.error "Failed to connect to AMQP server after multiple attempts: #{e}"
#     end  
#   rescue Exception => e
#     AmqpListenerState.mark_error!(e)
#     Rails.logger.error "Unknown error starting AMQP listener: #{e}"
#   end
# end

# if defined?(PhusionPassenger)
#   PhusionPassenger.on_event(:starting_worker_process) do |forked|
#     if forked
#       start_amqp_listener
#     end
#   end
# end