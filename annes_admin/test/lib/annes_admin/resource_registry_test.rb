require_relative "../../test_helper"

class AnnesAdmin::ResourceRegistryTest < AnnesAdmin::TestCase
  test "registers resources through configuration" do
    resource = AnnesAdmin.configuration.resource :customers, model: "Customer" do
      label "顧客"
      field :email, searchable: true, sortable: true
    end

    assert_same resource, AnnesAdmin.configuration.resources.fetch(:customers)
    assert_equal "顧客", resource.label
    assert_equal Customer, resource.model_class
    assert resource.searchable_attributes.include?(:email)
    assert resource.sortable_attributes.include?(:email)
  end

  test "rejects duplicate resources" do
    AnnesAdmin.configuration.resource :customers, model: "Customer"

    assert_raises(AnnesAdmin::ConfigurationError) do
      AnnesAdmin.configuration.resource :customers, model: "Customer"
    end
  end

  test "raises not found for unknown resources" do
    assert_raises(ActiveRecord::RecordNotFound) do
      AnnesAdmin.configuration.resources.fetch(:missing)
    end
  end

  test "raises configuration error for missing model class" do
    resource = AnnesAdmin.configuration.resource :missing_models, model: "MissingModel"

    assert_raises(AnnesAdmin::ConfigurationError) do
      resource.model_class
    end
  end

  test "removes only resources registered by the given source" do
    registry = AnnesAdmin::ResourceRegistry.new
    registry.register :customers, model: "Customer", source: :manual
    registry.register :projects, model: "Project", source: :loader

    registry.remove_source(:loader)

    assert registry.key?(:customers)
    assert_not registry.key?(:projects)
  end

  test "keeps source tracking in sync when clearing resources" do
    registry = AnnesAdmin::ResourceRegistry.new
    registry.register :customers, model: "Customer", source: :loader

    registry.clear
    registry.register :customers, model: "Customer", source: :manual

    assert registry.key?(:customers)
  end

  test "rejects duplicate resources across sources" do
    registry = AnnesAdmin::ResourceRegistry.new
    registry.register :customers, model: "Customer", source: :manual

    assert_raises(AnnesAdmin::ConfigurationError) do
      registry.register :customers, model: "Customer", source: :loader
    end
  end
end
