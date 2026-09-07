require "test_helper"

class DefinitionsTest < ActiveSupport::TestCase
  setup do
    @form = AnnesInquiry::Form.create!(key: "contact", name: "お問い合わせ")
    @version = @form.versions.create!(number: 1, title: "お問い合わせ")
    @field = @version.fields.create!(key: "kind", label: "種別", value_type: "single_choice", widget: "select")
    @field.options.create!(value: "question", label: "ご質問")
  end

  test "publishes then clones a complete editable version" do
    publish(@version)
    assert @version.reload.published?
    assert_not @field.update(label: "変更")
    assert_not @version.update(title: "変更")
    draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
    assert draft.draft?
    assert_equal 2, draft.number
    assert_equal "ご質問", draft.fields.first.options.first.label
    publish(draft)
    assert @version.reload.retired?
    assert_equal draft, @form.published_version
  end

  test "detects stale edits and refuses editing a published version" do
    AnnesInquiry::Definitions::DraftEditor.call(@version, expected_lock_version: 0) { |draft| draft.update!(title: "新しい題名") }
    assert_raises(ActiveRecord::StaleObjectError) do
      AnnesInquiry::Definitions::DraftEditor.call(@version, expected_lock_version: 0) { flunk "must not edit" }
    end
    publish(@version.reload)
    assert_raises(AnnesInquiry::Definitions::Error) do
      AnnesInquiry::Definitions::DraftEditor.call(@version, expected_lock_version: @version.lock_version) { flunk }
    end
  end

  test "refuses changing a published key type" do
    publish(@version)
    draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
    field = draft.fields.first
    field.options.destroy_all
    field.update!(value_type: "text", widget: "text")
    assert_raises(AnnesInquiry::Definitions::Error) { publish(draft) }
    assert draft.reload.draft?
    assert @version.reload.published?
  end

  test "validates settings and host contracts before retiring the old version" do
    @field.update!(placeholder: "不適合")
    assert_raises(AnnesInquiry::Definitions::Error) { publish(@version) }
    @field.update!(placeholder: nil)
    adapter = Object.new
    def adapter.validate_definition!(_version)
      raise AnnesInquiry::Definitions::Error, "emailが必要"
    end
    AnnesInquiry.configuration.adapters["contact"] = adapter
    assert_raises(AnnesInquiry::Definitions::Error) { publish(@version) }
    assert @version.reload.draft?
  ensure
    AnnesInquiry.configuration.adapters.clear
  end

  private
    def publish(version)
      AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: version.lock_version)
    end
end
