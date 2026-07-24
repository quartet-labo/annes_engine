require_relative "../test_helper"

class AnneAdmin::SubmitGuardTest < AnneAdmin::TestCase
  JAVASCRIPT_PATH = AnneAdmin::Engine.root.join(
    "app/assets/javascripts/anne_admin/submit_guard.js"
  )

  test "ships the submit guard JavaScript in the gem" do
    spec = Gem::Specification.load(
      AnneAdmin::Engine.root.join("anne_admin.gemspec").to_s
    )

    assert JAVASCRIPT_PATH.file?, "Expected #{JAVASCRIPT_PATH} to exist"
    assert_includes spec.files, "app/assets/javascripts/anne_admin/submit_guard.js"
  end
end
