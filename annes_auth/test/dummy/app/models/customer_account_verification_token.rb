class CustomerAccountVerificationToken < AnnesAuth::AccountVerificationToken
  belongs_to :customer_account,
    class_name: "CustomerAccount",
    foreign_key: :customer_account_id,
    inverse_of: :customer_account_verification_tokens

  def self.digest_for_customer_account_id(customer_account_id, code)
    digest_for_account_id(customer_account_id, code)
  end
end
