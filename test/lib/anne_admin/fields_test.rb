require_relative "../../test_helper"

class AnneAdmin::FieldsTest < AnneAdmin::TestCase
  test "builds field types" do
    assert_instance_of AnneAdmin::Fields::StringField, AnneAdmin::Fields::Base.build(:name, type: :string)
    assert_instance_of AnneAdmin::Fields::TextField, AnneAdmin::Fields::Base.build(:memo, type: :text)
    assert_instance_of AnneAdmin::Fields::NumberField, AnneAdmin::Fields::Base.build(:amount, type: :decimal)
    assert_instance_of AnneAdmin::Fields::BooleanField, AnneAdmin::Fields::Base.build(:active, type: :boolean)
    assert_instance_of AnneAdmin::Fields::EnumField, AnneAdmin::Fields::Base.build(:status, type: :enum)
    assert_instance_of AnneAdmin::Fields::AssociationField, AnneAdmin::Fields::Base.build(:customer, type: :association)
  end

  test "formats values" do
    customer = customers(:anan)

    assert_equal customer.email, AnneAdmin::Fields::Base.build(:email, type: :string).format(customer)
    assert_equal "-", AnneAdmin::Fields::Base.build(:company_name, type: :string).format(Customer.new)
  end

  test "formats enum labels" do
    project = projects(:embroidery)
    field = AnneAdmin::Fields::Base.build(:status, type: :enum, collection: Project::STATUSES)

    assert_equal Project::STATUSES.fetch(project.status), field.format(project)
  end

  test "uses display label for associations" do
    project = projects(:embroidery)
    field = AnneAdmin::Fields::Base.build(:customer, type: :association, label_method: :display_name)

    assert_equal project.customer.display_name, field.format(project)
  end
end
