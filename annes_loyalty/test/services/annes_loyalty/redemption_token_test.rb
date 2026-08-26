require_relative "../../test_helper"

class AnnesLoyalty::RedemptionTokenTest < AnnesLoyalty::TestCase
  test "generates opaque tokens and stable digests" do
    token = AnnesLoyalty::RedemptionToken.generate
    digest = AnnesLoyalty::RedemptionToken.digest(token)

    assert_not_empty token
    assert_not_equal token, digest
    assert_equal digest, AnnesLoyalty::RedemptionToken.digest(token)
  end
end
