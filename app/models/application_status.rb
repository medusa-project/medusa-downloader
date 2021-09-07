require 'json'

class ApplicationStatus < Object
    STATUS_OK = "OK"
    STATUS_SUCCESS = "Success"
    STATUS_ERROR = "Error"

    def self.query_application_status
        rclone_monit_status = `monit status rclone-mount | grep status | head -n 1 |  awk '{ print $2; }'`
        rclone_monit_status.chomp!

        rclone_path = `cat .monitrc | grep 'rclone-mount path' | awk '{ print $5; }' | sed -e 's/^"//' -e 's/"$//'`
        rclone_files = `ls #{rclone_path} | wc -l`.to_i
        rclone_files != 0 ? rclone_mount_status = STATUS_SUCCESS : rclone_mount_status = STATUS_ERROR
        
        rclone_monit_status == STATUS_OK && rclone_mount_status == STATUS_SUCCESS ? http_code = 200 : http_code = 500
        
        json_response = {"Rclone Monit Status" => rclone_monit_status, "Rclone Mount Status" => rclone_mount_status}.to_json

        return http_code, json_response
    end   
end