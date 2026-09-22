if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      begin
        Rails.logger.warn 'Initializing SQS connection'
        SqsPollerState.mark_starting!
        connector = SqsHelper::Connector.new(region: DOWNLOADER_CONFIG[:aws_region])

        Rails.logger.warn 'Starting SQS poller'
        poller = SqsHelper::Poller.new(connector, DOWNLOADER_CONFIG[:incoming_sqs_queue])
        SqsPollerState.mark_running!
        
        poller_thread = Thread.new do
          poller.start_polling(->(payload) {
            # Convert Hash to JSON string if needed (SQS poller may pre-parse)
            json_payload = payload.is_a?(String) ? payload : payload.to_json
            SqsRequestBridge.create_request(json_payload)
            SqsPollerState.mark_heartbeat!
          })
        end
        Kernel.at_exit do
          Rails.logger.warn 'Closing SQS poller'
          poller.stop_polling rescue nil
          poller_thread.join(5) rescue nil
          SqsPollerState.mark_stopped!
        end
      rescue Exception => e
        Rails.logger.error "Failed to initialize SQS connection: #{e}"
        SqsPollerState.mark_error!(e)
      end
    end
  end

  PhusionPassenger.on_event(:stopping_worker_process) do
    Rails.logger.warn 'Stopping SQS poller'
    SqsPollerState.mark_stopped!
  end
end