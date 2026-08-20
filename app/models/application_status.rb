require 'json'

class ApplicationStatus < Object
    STATUS_OK = "OK"
    STATUS_SUCCESS = "Success"
    STATUS_ERROR = "Error"

    def self.query_application_status
        amqp_listener_status = AmqpListenerState.status_payload
        delayed_job_status = delayed_job_status_payload

        statuses_ok = [
            amqp_listener_status['running'],
            delayed_job_status['running']
        ]
        statuses_ok.all? ? http_code = 200 : http_code = 500
        unless statuses_ok.all?
            Rails.logger.error "Application status check failed: AMQP listener running: #{amqp_listener_status['running']}, Delayed job running: #{delayed_job_status['running']}"
        end
        json_response = {
            "amqpListener" => amqp_listener_status,
            "delayedJobs" => delayed_job_status
        }.to_json

        return http_code, json_response
    end

    def self.delayed_job_status_payload
        running = delayed_job_worker_running

        {
            'status' => running ? 'running' : 'stopped',
            'running' => running,
            'workerCount' => running ? 1 : 0
        }
    rescue StandardError => e
        {
            'status' => 'error',
            'running' => false,
            'workerCount' => 0,
            'lastError' => e.to_s
        }
    end

    def self.delayed_job_worker_running
        system('pgrep -f "jobs:work" > /dev/null 2>&1')
    end
end