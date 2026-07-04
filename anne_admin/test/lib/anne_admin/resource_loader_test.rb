require "tmpdir"
require_relative "../../test_helper"

class AnneAdmin::ResourceLoaderTest < AnneAdmin::TestCase
  test "loads resource files from configured paths in sorted order" do
    Dir.mktmpdir do |dir|
      write_resource_file dir, "02_projects.rb", <<~RUBY
        AnneAdmin.resource :projects, model: "Project" do
          label "Projects"
        end
      RUBY
      write_resource_file dir, "01_customers.rb", <<~RUBY
        AnneAdmin.resource :customers, model: "Customer" do
          label "Customers"
        end
      RUBY

      AnneAdmin.configuration.resource_paths << dir
      AnneAdmin.load_resources!

      assert_equal %w[customers projects], AnneAdmin.configuration.resources.map(&:name)
    end
  end

  test "reloads resource files without duplicate registration" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "customers.rb")
      File.write path, <<~RUBY
        AnneAdmin.resource :customers, model: "Customer" do
          label "First"
        end
      RUBY

      AnneAdmin.configuration.resource_paths << dir
      AnneAdmin.load_resources!
      assert_equal "First", AnneAdmin.configuration.resources.fetch(:customers).label

      File.write path, <<~RUBY
        AnneAdmin.resource :customers, model: "Customer" do
          label "Second"
        end
      RUBY
      AnneAdmin.load_resources!

      assert_equal "Second", AnneAdmin.configuration.resources.fetch(:customers).label
    end
  end

  test "rejects duplicate resources inside loaded files" do
    Dir.mktmpdir do |dir|
      write_resource_file dir, "customers.rb", 'AnneAdmin.resource :customers, model: "Customer"'
      write_resource_file dir, "duplicate_customers.rb", 'AnneAdmin.resource :customers, model: "Customer"'

      AnneAdmin.configuration.resource_paths << dir

      assert_raises AnneAdmin::ConfigurationError do
        AnneAdmin.load_resources!
      end
    end
  end

  test "rejects resource file that duplicates a manual resource" do
    Dir.mktmpdir do |dir|
      AnneAdmin.configuration.resource :customers, model: "Customer"
      write_resource_file dir, "customers.rb", 'AnneAdmin.resource :customers, model: "Customer"'

      AnneAdmin.configuration.resource_paths << dir

      assert_raises AnneAdmin::ConfigurationError do
        AnneAdmin.load_resources!
      end
    end
  end

  private
    def write_resource_file(dir, filename, content)
      File.write File.join(dir, filename), content
    end
end
