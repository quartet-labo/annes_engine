require "tmpdir"
require_relative "../../test_helper"

class AnnesAdmin::ResourceLoaderTest < AnnesAdmin::TestCase
  test "loads resource files from configured paths in sorted order" do
    Dir.mktmpdir do |dir|
      write_resource_file dir, "02_projects.rb", <<~RUBY
        AnnesAdmin.resource :projects, model: "Project" do
          label "Projects"
        end
      RUBY
      write_resource_file dir, "01_customers.rb", <<~RUBY
        AnnesAdmin.resource :customers, model: "Customer" do
          label "Customers"
        end
      RUBY

      AnnesAdmin.configuration.resource_paths << dir
      AnnesAdmin.load_resources!

      assert_equal %w[customers projects], AnnesAdmin.configuration.resources.map(&:name)
    end
  end

  test "reloads resource files without duplicate registration" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "customers.rb")
      File.write path, <<~RUBY
        AnnesAdmin.resource :customers, model: "Customer" do
          label "First"
        end
      RUBY

      AnnesAdmin.configuration.resource_paths << dir
      AnnesAdmin.load_resources!
      assert_equal "First", AnnesAdmin.configuration.resources.fetch(:customers).label

      File.write path, <<~RUBY
        AnnesAdmin.resource :customers, model: "Customer" do
          label "Second"
        end
      RUBY
      AnnesAdmin.load_resources!

      assert_equal "Second", AnnesAdmin.configuration.resources.fetch(:customers).label
    end
  end

  test "rejects duplicate resources inside loaded files" do
    Dir.mktmpdir do |dir|
      write_resource_file dir, "customers.rb", 'AnnesAdmin.resource :customers, model: "Customer"'
      write_resource_file dir, "duplicate_customers.rb", 'AnnesAdmin.resource :customers, model: "Customer"'

      AnnesAdmin.configuration.resource_paths << dir

      assert_raises AnnesAdmin::ConfigurationError do
        AnnesAdmin.load_resources!
      end
    end
  end

  test "rejects resource file that duplicates a manual resource" do
    Dir.mktmpdir do |dir|
      AnnesAdmin.configuration.resource :customers, model: "Customer"
      write_resource_file dir, "customers.rb", 'AnnesAdmin.resource :customers, model: "Customer"'

      AnnesAdmin.configuration.resource_paths << dir

      assert_raises AnnesAdmin::ConfigurationError do
        AnnesAdmin.load_resources!
      end
    end
  end

  private
    def write_resource_file(dir, filename, content)
      File.write File.join(dir, filename), content
    end
end
