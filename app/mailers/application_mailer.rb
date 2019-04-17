class ApplicationMailer < ActionMailer::Base
  default from: 'no-reply@download.library.illinois.edu'
  layout 'mailer'
end
