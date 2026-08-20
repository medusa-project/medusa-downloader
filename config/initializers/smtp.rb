unless Rails.env.test?
  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = DOWNLOADER_CONFIG[:smtp]
end