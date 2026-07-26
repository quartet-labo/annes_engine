require_relative "../../test_helper"

class AnneLoyalty::RedemptionTokenTest < AnneLoyalty::TestCase
  test "generates opaque tokens and stable digests" do
    token = AnneLoyalty::RedemptionToken.generate
    digest = AnneLoyalty::RedemptionToken.digest(token)

    assert_not_empty token
    assert_not_equal token, digest
    assert_equal digest, AnneLoyalty::RedemptionToken.digest(token)
  end
end
