require_relative "../test_helper"

class AnneAdmin::StylesheetTest < AnneAdmin::TestCase
  STYLESHEET_PATH = AnneAdmin::Engine.root.join(
    "app/assets/stylesheets/anne_admin/application.css"
  )

  test "ships the action stylesheet in the gem" do
    spec = Gem::Specification.load(
      AnneAdmin::Engine.root.join("anne_admin.gemspec").to_s
    )

    assert STYLESHEET_PATH.file?, "Expected #{STYLESHEET_PATH} to exist"
    assert_includes spec.files, "app/assets/stylesheets/anne_admin/application.css"
  end

  test "defines host independent action states" do
    stylesheet = STYLESHEET_PATH.read

    assert_match(/\.anne-admin-action\s*\{/, stylesheet)
    assert_match(/\.anne-admin-action--primary\s*\{[^}]*background-color:\s*#0f172a;/m, stylesheet)
    assert_match(/\.anne-admin-action--primary\s*\{[^}]*color:\s*#fff(?:fff)?;/m, stylesheet)
    assert_match(/\.anne-admin-action--primary:hover\s*\{[^}]*background-color:\s*#334155;/m, stylesheet)
    assert_match(/\.anne-admin-action:focus-visible\s*\{[^}]*outline:\s*2px\s+solid/m, stylesheet)
    assert_match(/\.anne-admin-action:disabled,\s*\.anne-admin-action\[aria-disabled="true"\]/m, stylesheet)
    refute_match(/var\(--(?:tw|color)-/, stylesheet)
    refute_includes stylesheet, "!important"
  end
end
