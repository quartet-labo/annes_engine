class ApplicationMailer < ActionMailer::Base
  default from: -> { AnneAuth.configuration.mailer_from }
  layout "mailer"
end
