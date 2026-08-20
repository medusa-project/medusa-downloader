require 'fileutils'
require 'json'

class AmqpListenerState
  STATE_DIR = (ENV['RUN_DIR'] || Rails.root.join('run')).to_s
  HEARTBEAT_INTERVAL = 30
  HEARTBEAT_TIMEOUT = 90

  class << self
    def mark_starting!(pid = Process.pid)
      write_state(pid,
        'status' => 'starting',
        'pid' => pid,
        'started_at' => nil,
        'last_error' => nil,
        'last_error_at' => nil,
        'last_heartbeat_at' => nil
      )
    end

    def mark_running!(connection:, pid: Process.pid)
      write_state(pid,
        'status' => 'running',
        'pid' => pid,
        'started_at' => Time.now.utc.iso8601,
        'last_error' => nil,
        'last_error_at' => nil,
        'last_heartbeat_at' => Time.now.utc.iso8601
      )
      start_heartbeat_thread(pid)
    end

    def mark_error!(error, pid = Process.pid)
      write_state(pid,
        'status' => 'error',
        'pid' => pid,
        'last_error' => error.to_s,
        'last_error_at' => Time.now.utc.iso8601,
        'last_heartbeat_at' => nil
      )
    end

    def mark_stopped!(pid = Process.pid)
      write_state(pid, 'status' => 'stopped', 'pid' => pid, 'last_heartbeat_at' => nil)
    end

    def running?
      status_payload['running']
    end

    def status_payload
      workers = all_worker_states
      running_workers = workers.select { |w| w['running'] }
      any_running = running_workers.any?

      {
        'status' => any_running ? 'running' : (workers.any? ? workers.first['status'] : 'not_started'),
        'running' => any_running,
        'workerCount' => running_workers.size,
        'workers' => workers,
        'startedAt' => running_workers.first&.dig('startedAt'),
        'lastError' => workers.map { |w| w['lastError'] }.compact.first,
        'lastErrorAt' => workers.map { |w| w['lastErrorAt'] }.compact.first
      }
    end

    private

    def state_file(pid)
      File.join(STATE_DIR, "amqp_listener_state_#{pid}.json")
    end

    def all_worker_states
      FileUtils.mkdir_p(STATE_DIR)
      Dir.glob(File.join(STATE_DIR, 'amqp_listener_state_*.json')).filter_map do |file|
        pid = File.basename(file, '.json').split('_').last.to_i
        state = read_state(pid)
        next if state.empty?

        # Remove stale files for processes that are no longer running
        unless process_alive?(pid)
          File.delete(file) rescue nil
          next
        end

        heartbeat_at = state['last_heartbeat_at'] ? Time.parse(state['last_heartbeat_at']) : nil
        current = state['status'] || 'not_started'
        running = current == 'running' && heartbeat_at&.>(HEARTBEAT_TIMEOUT.seconds.ago)

        {
          'status' => running ? 'running' : (current == 'running' ? 'disconnected' : current),
          'running' => running,
          'pid' => pid,
          'startedAt' => state['started_at'],
          'lastError' => state['last_error'],
          'lastErrorAt' => state['last_error_at']
        }
      end
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def read_state(pid)
      file = state_file(pid)
      return {} unless File.exist?(file)
      JSON.parse(File.read(file))
    rescue JSON::ParserError, Errno::ENOENT
      {}
    end

    def write_state(pid, updates)
      FileUtils.mkdir_p(STATE_DIR)
      file = state_file(pid)
      tmp_file = "#{file}.#{Process.pid}.tmp"
      File.write(tmp_file, read_state(pid).merge(updates).to_json)
      File.rename(tmp_file, file)
    rescue StandardError => e
      Rails.logger.error "Failed to write AMQP listener state: #{e}"
    end

    def start_heartbeat_thread(pid)
      Thread.new do
        loop do
          sleep HEARTBEAT_INTERVAL
          state = read_state(pid)
          break unless state['status'] == 'running'
          write_state(pid, 'last_heartbeat_at' => Time.now.utc.iso8601)
        end
      rescue StandardError => e
        Rails.logger.error "AMQP heartbeat thread error: #{e}"
      end
    end
  end
end