require_relative "../../test_helper"

class AnneAdmin::ResourceRegistryTest < AnneAdmin::TestCase
  test "registers resources through configuration" do
    resource = AnneAdmin.configuration.resource :customers, model: "Customer" do
      label "顧客"
      field :email, searchable: true, sortable: true
    end

    assert_same resource, AnneAdmin.configuration.resources.fetch(:customers)
    assert_equal "顧客", resource.label
    assert_equal Customer, resource.model_class
    assert resource.searchable_attributes.include?(:email)
    assert resource.sortable_attributes.include?(:email)
  end

  test "rejects duplicate resources" do
    AnneAdmin.configuration.resource :customers, model: "Customer"

    assert_raises(AnneAdmin::ConfigurationError) do
      AnneAdmin.configuration.resource :customers, model: "Customer"
    end
  end

  test "raises not found for unknown resources" do
    assert_raises(ActiveRecord::RecordNotFound) do
      AnneAdmin.configuration.resources.fetch(:missing)
    end
  end

  test "raises configuration error for missing model class" do
    resource = AnneAdmin.configuration.resource :missing_models, model: "MissingModel"

    assert_raises(AnneAdmin::ConfigurationError) do
      resource.model_class
    end
  end
end
