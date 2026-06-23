require_relative "../../test_helper"

class AnneAdmin::ResourceConfigTest < AnneAdmin::TestCase
  test "tracks fields and permitted attributes" do
    resource = AnneAdmin::ResourceConfig.new(:customers, model: "Customer")
    resource.field :email, searchable: true, sortable: true
    resource.field :created_at, type: :datetime, permitted: false, sortable: true

    assert_equal %i[email], resource.permitted_attributes
    assert_equal %i[email created_at], resource.fields.map(&:name)
    assert resource.searchable_attributes.include?(:email)
    assert resource.sortable_attributes.include?(:created_at)
  end

  test "explicit permitted attributes override field defaults" do
    resource = AnneAdmin::ResourceConfig.new(:customers, model: "Customer")
    resource.fields :company_name, :contact_name
    resource.permitted_attributes :contact_name

    assert_equal %i[contact_name], resource.permitted_attributes
  end

  test "supports named scopes and custom actions" do
    resource = AnneAdmin::ResourceConfig.new(:customers, model: "Customer")
    resource.scope :recent, label: "Recent"
    resource.custom_action :invite, method: :post, scope: :member, label: "Invite" do
    end

    assert_equal "Recent", resource.scopes["recent"][:label]
    assert_equal [ "invite" ], resource.member_custom_actions.map(&:name)
  end

  test "applies configured includes to base relation" do
    resource = AnneAdmin::ResourceConfig.new(:projects, model: "Project")
    resource.includes :customer

    assert_includes resource.relation.includes_values, :customer
  end
end
