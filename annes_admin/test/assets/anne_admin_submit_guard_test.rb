require_relative "../test_helper"

class AnnesAdmin::SubmitGuardTest < AnnesAdmin::TestCase
  JAVASCRIPT_PATH = AnnesAdmin::Engine.root.join(
    "app/assets/javascripts/annes_admin/submit_guard.js"
  )

  test "ships the submit guard JavaScript in the gem" do
    spec = Gem::Specification.load(
      AnnesAdmin::Engine.root.join("annes_admin.gemspec").to_s
    )

    assert JAVASCRIPT_PATH.file?, "Expected #{JAVASCRIPT_PATH} to exist"
    assert_includes spec.files, "app/assets/javascripts/annes_admin/submit_guard.js"
  end
end
