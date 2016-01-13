if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      begin
        connection = Bunny.new(Config.instance.amqp)
        connection.start
        Kernel.at_exit do
          connection.close rescue nil
        end
        Rails.logger.error "Starting AMQP listener"
        channel = connection.create_channel
        queue = channel.queue(Config.instance.incoming_queue, durable: true)
        queue.subscribe do |delivery_info, properties, payload|
          begin
            Request.from_message(payload)
            Rails.logger.info "Created request from #{payload}"
          rescue Exception => e
            Rails.logger.error "Failed to create request from #{payload}: #{e}"
          end
        end
      rescue Exception => e
        Rails.logger.error "Unknown erorr starting AMQP listener: #{e}"
      end
    end
  end
end