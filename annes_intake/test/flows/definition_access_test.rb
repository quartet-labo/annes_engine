require "test_helper"
require_relative "../support/flow_test_support"

class DefinitionAccessTest < ActionDispatch::IntegrationTest
  include FlowTestSupport

  class RestrictedAuthorizer < TestDefinitionAuthorizer
    attr_accessor :excluded_class, :excluded_id, :denied_class
    def scope_definitions(relation, context:)
      return relation unless relation.klass == excluded_class
      excluded_id ? relation.where.not(id: excluded_id) : relation.none
    end
    def authorize!(action:, record:, context:)
      !record || record.class != denied_class
    end
  end

  setup do
    build_flow
    @previous_authorizer = AnnesIntake.configuration.definition_authorizer
    @authorizer = RestrictedAuthorizer.new
    AnnesIntake.configuration.definition_authorizer = @authorizer
    AnnesIntake.configuration.admin_authenticator = ->(_) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(*) { true }
  end
  teardown do
    AnnesIntake.configuration.definition_authorizer = @previous_authorizer
    AnnesIntake.configuration.admin_authenticator = nil
    AnnesIntake.configuration.admin_authorizer = nil
    AnnesIntake.configuration.adapters.clear
  end

  test "creation rolls back parent and version for scoped or record authorization denials" do
    [[:form, AnnesIntake::Form, AnnesIntake::FormVersion], [:flow, AnnesIntake::Flow, AnnesIntake::FlowVersion]].each do |kind, parent, version|
      [parent, version].each do |denied|
        [:excluded_class, :denied_class].each do |restriction|
          @authorizer.public_send("#{restriction}=", denied)
          assert_no_difference(["#{parent}.count", "#{version}.count"]) do
            post "/intake/admin/#{kind}s", params: {kind => {key: "restricted", name: "Restricted"}}
          end
          assert_response restriction == :excluded_class ? :not_found : :forbidden
          @authorizer.public_send("#{restriction}=", nil)
        end
      end
      assert_difference(["#{parent}.count", "#{version}.count"], 1) do
        post "/intake/admin/#{kind}s", params: {kind => {key: "allowed", name: "Allowed"}}
        assert_response :see_other
      end
      follow_redirect!
      assert_response :success
    end
  end

  test "form and flow histories exclude versions outside their individual scope" do
    form_version = @version.steps.first.form_version
    form = form_version.form
    hidden = form.versions.create!(number: 2, title: "Hidden form version")
    @authorizer.excluded_class, @authorizer.excluded_id = AnnesIntake::FormVersion, hidden.id
    get "/intake/admin/forms/#{form.id}"
    assert_response :success
    assert_select "a[href='/intake/admin/versions/#{hidden.id}']", count: 0
    assert_select "a[href='/intake/admin/versions/#{form_version.id}']", count: 1
    patch "/intake/admin/forms/#{form.id}", params: {lock_version: form.lock_version, form: {name: ""}}
    assert_response :unprocessable_entity
    assert_select "a[href='/intake/admin/versions/#{hidden.id}']", count: 0

    hidden_flow = @flow.versions.create!(number: 2, title: "Hidden flow version")
    @authorizer.excluded_class, @authorizer.excluded_id = AnnesIntake::FlowVersion, hidden_flow.id
    get "/intake/admin/flows/#{@flow.id}"
    assert_response :success
    assert_no_match "Hidden flow version", response.body
    assert_select "h2", text: /Intake/
  end

  test "hidden fields are absent from lists and block aggregate previews and rules" do
    version = @version.steps.first.form_version
    field = version.fields.first
    @authorizer.excluded_class, @authorizer.excluded_id = AnnesIntake::Field, field.id
    get "/intake/admin/versions/#{version.id}"
    assert_response :success
    assert_select "a[href='/intake/admin/fields/#{field.id}/edit']", count: 0
    ["/intake/admin/versions/#{version.id}/preview", "/intake/admin/flows/#{@flow.id}/versions/#{@version.id}/preview", "/intake/admin/flows/#{@flow.id}"].each do |path|
      get path
      assert_response :not_found
    end
    @authorizer.excluded_class = nil
    get "/intake/admin/versions/#{version.id}/preview"
    assert_response :success
    assert_select "input[name='intake[name]']"
    get "/intake/admin/flows/#{@flow.id}"
    assert_response :success
  end

  test "referenced form version scopes also protect aggregate flow rendering" do
    @authorizer.excluded_class = AnnesIntake::FormVersion
    @authorizer.excluded_id = @version.steps.first.form_version_id
    get "/intake/admin/flows/#{@flow.id}"
    assert_response :not_found
    get "/intake/admin/flows/#{@flow.id}/versions/#{@version.id}/preview"
    assert_response :not_found
  end
end
