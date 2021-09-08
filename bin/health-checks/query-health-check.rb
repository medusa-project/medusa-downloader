require 'net/http'
require 'logger'
require 'json'

logger = Logger.new('/home/downloader/log/health_check_status.log', 1, 500000)

instance_id = File.open('/var/lib/cloud/data/instance-id', &:readline).strip    

downloader_uri = URI('https://demo.download.library.illinois.edu/downloads/status')
downloader_response = Net::HTTP.get_response(downloader_uri)

begin
    rclone_monit_status = JSON.parse(downloader_response.body)['rcloneMonitStatus']
    rclone_mount_status = JSON.parse(downloader_response.body)['rcloneMountStatus']
    downloader_response_body = {"rclone_monit_status" => rclone_monit_status, "rclone_mount_status" => rclone_mount_status}

    downloader_log = {"InstanceId" => instance_id, "downloader_code" => downloader_response.code, "downloader_message" => downloader_response_body}
rescue JSON::ParserError => e
    downloader_log = {"InstanceId" => instance_id, "downloader_code" => downloader_response.code, "downloader_message" => "Error parsing downloader health check JSON"}
end
logger.info(downloader_log.to_json)
