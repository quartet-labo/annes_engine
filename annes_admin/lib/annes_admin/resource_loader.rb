require "pathname"

module AnnesAdmin
  class ResourceLoader
    def initialize(configuration)
      @configuration = configuration
    end

    def load
      configuration.resources.remove_source(:loader)
      configuration.with_resource_source(:loader) do
        resource_files.each { |path| Kernel.load path.to_s }
      end
    rescue StandardError, ScriptError
      configuration.resources.remove_source(:loader)
      raise
    end

    private
      attr_reader :configuration

      def resource_files
        resource_paths.flat_map do |path|
          Dir[File.join(path.to_s, "**", "*.rb")]
        end.sort.map { |path| Pathname.new(path) }
      end

      def resource_paths
        (configuration.default_resource_paths + configuration.resource_paths)
          .map { |path| Pathname.new(path.to_s).expand_path }
          .uniq
          .select(&:directory?)
      end
  end
end
