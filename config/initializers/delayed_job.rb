Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', "delayed_job_#{Rails.env}.log"))
Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.default_priority = 50
