require 'json'

class ApplicationStatus < Object
    STATUS_OK = "OK"
    STATUS_SUCCESS = "Success"
    STATUS_ERROR = "Error"

    def self.query_application_status
        mountpoint_monit_status = `monit -B summary mountpoint-mount | tail -n 1 | awk '{print $2}'`
        mountpoint_monit_status.chomp!
        mountpoint_monit_status.strip!

        mountpoint_path = `df | grep mountpoint-s3 | awk '{print $6}'`
        mountpoint_files = `ls #{mountpoint_path} | wc -l`.to_i
        mountpoint_files != 0 ? mountpoint_mount_status = STATUS_SUCCESS : mountpoint_mount_status = STATUS_ERROR
        
        mountpoint_monit_status == STATUS_OK && mountpoint_mount_status == STATUS_SUCCESS ? http_code = 200 : http_code = 500
        
        json_response = {"mountpointMonitStatus" => mountpoint_monit_status, "mountpointMountStatus" => mountpoint_mount_status}.to_json

        return http_code, json_response
    end   
end