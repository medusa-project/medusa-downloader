require 'rake'

namespace :downloader do
  desc 'Delete old requests and associated file system resources'
  task :delete_old_requests => :environment do
    Request.where('updated_at < ?', Time.now - 14.days).find_each do |request|
      request.destroy!
    end
  end

end