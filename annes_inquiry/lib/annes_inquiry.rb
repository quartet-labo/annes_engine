require "rails"
require "annes_inquiry/version"
require "annes_inquiry/configuration"
require "annes_inquiry/type_registry"
require "annes_inquiry/engine"

module AnnesInquiry
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
  end
end
