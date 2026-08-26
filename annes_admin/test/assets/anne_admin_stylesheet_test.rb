require_relative "../test_helper"

class AnnesAdmin::StylesheetTest < AnnesAdmin::TestCase
  STYLESHEET_PATH = AnnesAdmin::Engine.root.join(
    "app/assets/stylesheets/annes_admin/application.css"
  )

  test "ships the action stylesheet in the gem" do
    spec = Gem::Specification.load(
      AnnesAdmin::Engine.root.join("annes_admin.gemspec").to_s
    )

    assert STYLESHEET_PATH.file?, "Expected #{STYLESHEET_PATH} to exist"
    assert_includes spec.files, "app/assets/stylesheets/annes_admin/application.css"
  end

  test "defines host independent action states" do
    stylesheet = STYLESHEET_PATH.read

    assert_match(/\.annes-admin-action\s*\{/, stylesheet)
    assert_match(/\.annes-admin-action--primary\s*\{[^}]*background-color:\s*#0f172a;/m, stylesheet)
    assert_match(/\.annes-admin-action--primary\s*\{[^}]*color:\s*#fff(?:fff)?;/m, stylesheet)
    assert_match(/\.annes-admin-action--primary:hover\s*\{[^}]*background-color:\s*#334155;/m, stylesheet)
    assert_match(/\.annes-admin-action:focus-visible\s*\{[^}]*outline:\s*2px\s+solid/m, stylesheet)
    assert_match(/\.annes-admin-action:disabled,\s*\.annes-admin-action\[aria-disabled="true"\]/m, stylesheet)
    assert_match(/\.annes-admin-action:disabled,[^}]*cursor:\s*wait;/m, stylesheet)
    refute_match(/var\(--(?:tw|color)-/, stylesheet)
    refute_includes stylesheet, "!important"
  end
end
