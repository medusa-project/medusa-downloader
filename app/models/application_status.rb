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
        system('pid_file=run/delayed_job.pid; [ -s "$pid_file" ] && pid=$(cat "$pid_file") && kill -0 "$pid" 2>/dev/null')
    end
end