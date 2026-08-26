require_relative "../../test_helper"

class AnnesAdmin::QueryTest < AnnesAdmin::TestCase
  test "searches allowlisted attributes" do
    resource = AnnesAdmin::ResourceConfig.new(:customers, model: "Customer")
    resource.searchable_by :contact_name

    query = AnnesAdmin::Query.new(resource, { q: customers(:anan).contact_name })

    assert_includes query.records, customers(:anan)
  end

  test "ignores non-text searchable attributes" do
    resource = AnnesAdmin::ResourceConfig.new(:customers, model: "Customer")
    resource.searchable_by :id

    query = AnnesAdmin::Query.new(resource, { q: customers(:anan).id.to_s })

    assert_equal Customer.count, query.total_count
  end

  test "ignores non-allowlisted sort params" do
    resource = AnnesAdmin::ResourceConfig.new(:customers, model: "Customer")

    query = AnnesAdmin::Query.new(resource, { sort: "email", direction: "desc" })

    assert_no_match(/ORDER BY "customers"."email"/, query.relation.to_sql)
  end

  test "applies allowlisted sort params" do
    resource = AnnesAdmin::ResourceConfig.new(:customers, model: "Customer")
    resource.sortable_by :email

    query = AnnesAdmin::Query.new(resource, { sort: "email", direction: "desc" })

    assert_match(/ORDER BY "customers"."email" DESC/, query.relation.to_sql)
  end

  test "caps pagination size" do
    AnnesAdmin.configuration.max_per_page = 1
    resource = AnnesAdmin::ResourceConfig.new(:customers, model: "Customer")
    query = AnnesAdmin::Query.new(resource, { per_page: 500 })

    assert_equal 1, query.records.length
  end

  test "uses an injected base relation" do
    resource = AnnesAdmin::ResourceConfig.new(:customers, model: "Customer")
    query = AnnesAdmin::Query.new(resource, {}, relation: Customer.where(email: customers(:anan).email))

    assert_equal [customers(:anan)], query.records.to_a
  end
end
