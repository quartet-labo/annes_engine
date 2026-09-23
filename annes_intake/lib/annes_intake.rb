require "annes_form_kit"
require "rails"
require "annes_intake/version"
require "annes_intake/configuration"
require "annes_intake/type_registry"
require "annes_intake/engine"

module AnnesIntake
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
  end
end
