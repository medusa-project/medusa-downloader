class ErrorMailer < ApplicationMailer

  default to: Config.admin_email
  default subject: 'Medusa Downloader error'
  default from: 'no-reply@library.illinois.edu'

  def parsing_error(message)
    @message = message
    mail
  end

end
