if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      begin
        AmqpListenerState.mark_starting!
        connection = Bunny.new(Settings.amqp.to_h)
        connection.start
        Kernel.at_exit do
          AmqpListenerState.mark_stopped!
          connection.close rescue nil
        end
        Rails.logger.error 'Starting AMQP listener'
        channel = connection.create_channel
        queue = channel.queue(Settings.incoming_queue, durable: true)
        AmqpListenerState.mark_running!(connection: connection, queue_name: Settings.incoming_queue)
        queue.subscribe do |delivery_info, properties, payload|
          begin
            AmqpRequestBridge.create_request(payload)
            Rails.logger.info "Created request from #{payload}"
          rescue Exception => e
            Rails.logger.error "Failed to create request from #{payload}: #{e}"
          end
        end
      rescue Exception => e
        AmqpListenerState.mark_error!(e)
        Rails.logger.error "Unknown error starting AMQP listener: #{e}"
      end
    end
  end
end