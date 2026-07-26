require "test_helper"

class ReceiptTest < ActiveSupport::TestCase
  test "assigns a stable receipt source key for loyalty idempotency" do
    receipt = Receipt.create!(
      customer: Customer.create!(name: "山田 太郎"),
      amount_cents: 2_500,
      purchased_at: Time.current
    )

    assert_match(/\AR-[0-9A-F]{8}\z/, receipt.receipt_number)
    assert_equal receipt.receipt_number, receipt.loyalty_source_key
  end
end
