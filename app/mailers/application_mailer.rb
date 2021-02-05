class ApplicationMailer < ActionMailer::Base
  default from: 'no-reply@library.illinois.edu'
  layout 'mailer'
end
