require 'json'

class ApplicationStatus < Object
    def self.query_application_status
        rclone_status = `monit status rclone-mount | grep status | head -n 1 |  awk '{ print $2; }'`
        rclone_path = `cat .monitrc | grep 'rclone-mount path' | awk '{ print $5; }' | sed -e 's/^"//' -e 's/"$//'`
        rclone_mounted = `ls #{rclone_path} | wc -l`
        json_response = {"Rclone Monit Status" => rclone_status, "Rclone Mount Status" => rclone_mounted}.to_json
    end   
end     