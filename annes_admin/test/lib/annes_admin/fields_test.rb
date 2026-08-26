require_relative "../../test_helper"

class AnnesAdmin::FieldsTest < AnnesAdmin::TestCase
  test "builds field types" do
    assert_instance_of AnnesAdmin::Fields::StringField, AnnesAdmin::Fields::Base.build(:name, type: :string)
    assert_instance_of AnnesAdmin::Fields::TextField, AnnesAdmin::Fields::Base.build(:memo, type: :text)
    assert_instance_of AnnesAdmin::Fields::NumberField, AnnesAdmin::Fields::Base.build(:amount, type: :decimal)
    assert_instance_of AnnesAdmin::Fields::BooleanField, AnnesAdmin::Fields::Base.build(:active, type: :boolean)
    assert_instance_of AnnesAdmin::Fields::EnumField, AnnesAdmin::Fields::Base.build(:status, type: :enum)
    assert_instance_of AnnesAdmin::Fields::AssociationField, AnnesAdmin::Fields::Base.build(:customer, type: :association)
  end

  test "formats values" do
    customer = customers(:anan)

    assert_equal customer.email, AnnesAdmin::Fields::Base.build(:email, type: :string).format(customer)
    assert_equal "-", AnnesAdmin::Fields::Base.build(:company_name, type: :string).format(Customer.new)
  end

  test "formats enum labels" do
    project = projects(:embroidery)
    field = AnnesAdmin::Fields::Base.build(:status, type: :enum, collection: Project::STATUSES)

    assert_equal Project::STATUSES.fetch(project.status), field.format(project)
  end

  test "uses display label for associations" do
    project = projects(:embroidery)
    field = AnnesAdmin::Fields::Base.build(:customer, type: :association, label_method: :display_name)

    assert_equal project.customer.display_name, field.format(project)
  end
end
