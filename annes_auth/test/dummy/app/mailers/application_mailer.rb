class ApplicationMailer < ActionMailer::Base
  default from: -> { AnnesAuth.configuration.mailer_from }
  layout "mailer"
end
