require "test_helper"
require_relative "../support/preview_definition"

class PreviewTest < ActionDispatch::IntegrationTest
  include PreviewDefinition
  setup { @version = create_preview_definition }

  test "renders all widgets escaped labels hints and timezone without JavaScript" do
    get "/preview/#{@version.id}"
    assert_response :success
    assert_select "form[enctype='multipart/form-data']"
    assert_select "input[placeholder='例：入力してください']"
    assert_select "textarea"
    assert_select "input[type=email]"
    assert_select "input[type=tel]"
    assert_select "input[type=datetime-local]"
    assert_select "select[multiple]"
    assert_select "input[type=file]"
    assert_select "script", count: 0
    assert_includes response.body, "&lt;script&gt;unsafe&lt;/script&gt;"
    assert_includes response.body, "Asia/Tokyo"
  end

  test "preview returns field errors with original value and never creates a submission" do
    assert_no_difference("AnnesInquiry::Submission.count") do
      post "/preview/#{@version.id}", params: { inquiry: { integer_number: "12bad" } }
      assert_response :unprocessable_entity
      assert_select "input[name='inquiry[integer_number]'][value='12bad'][aria-invalid='true']"
      assert_select "[role=alert]"
      post "/preview/#{@version.id}", params: { inquiry: { date_date: "2026-02-30", datetime_datetime: "2026-09-06T25:00" } }
      assert_response :unprocessable_entity
      assert_select "input[type=text][value='2026-02-30']"
      assert_select "input[type=text][value='2026-09-06T25:00']"
      post "/preview/#{@version.id}", params: { inquiry: { integer_number: "12" } }
      assert_response :success
    end
  end
end
