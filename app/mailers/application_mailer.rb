class ApplicationMailer < ActionMailer::Base
  default from: 'no-reply@medusa.illinois.edu'
  layout 'mailer'
end
