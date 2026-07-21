class AmqpListenerState
  class << self
    def mark_starting!
      synchronize do
        @status = 'starting'
        @started_at = nil
        @last_error = nil
        @last_error_at = nil
      end
    end

    def mark_running!(connection:, queue_name:)
      synchronize do
        @status = 'running'
        @connection = connection
        @queue_name = queue_name
        @started_at = Time.now.utc
        @last_error = nil
        @last_error_at = nil
      end
    end

    def mark_error!(error)
      synchronize do
        @status = 'error'
        @last_error = error.to_s
        @last_error_at = Time.now.utc
      end
    end

    def mark_stopped!
      synchronize do
        @status = 'stopped'
        @connection = nil
      end
    end

    def running?
      status_payload['running']
    end

    def status_payload
      synchronize do
        current = @status || 'not_started'
        running = current == 'running' && connection_connected?
        current_status = running ? 'running' : (current == 'running' ? 'disconnected' : current)

        {
          'status' => current_status,
          'running' => running,
          'queue' => @queue_name,
          'startedAt' => @started_at&.iso8601,
          'lastError' => @last_error,
          'lastErrorAt' => @last_error_at&.iso8601
        }
      end
    end

    private

    def synchronize
      mutex.synchronize { yield }
    end

    def mutex
      @mutex ||= Mutex.new
    end

    def connection_connected?
      return false unless @connection

      if @connection.respond_to?(:connected?)
        @connection.connected?
      elsif @connection.respond_to?(:open?)
        @connection.open?
      else
        true
      end
    rescue StandardError
      false
    end
  end
end