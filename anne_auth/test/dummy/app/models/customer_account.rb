class CustomerAccount < AnneAuth::Account
  include CustomerAccountProfile
  include CustomerAccountProjectAccess

  has_many :customer_sessions,
    class_name: "CustomerSession",
    foreign_key: :customer_account_id,
    dependent: :destroy,
    inverse_of: :customer_account
  has_many :customer_account_identities,
    class_name: "CustomerAccountIdentity",
    foreign_key: :customer_account_id,
    dependent: :destroy,
    inverse_of: :customer_account
  has_many :customer_account_verification_tokens,
    class_name: "CustomerAccountVerificationToken",
    foreign_key: :customer_account_id,
    dependent: :destroy,
    inverse_of: :customer_account
  has_many :customer_account_password_reset_tokens,
    class_name: "CustomerAccountPasswordResetToken",
    foreign_key: :customer_account_id,
    dependent: :destroy,
    inverse_of: :customer_account
  has_many :customer_account_invitation_tokens,
    class_name: "CustomerAccountInvitationToken",
    foreign_key: :customer_account_id,
    dependent: :destroy,
    inverse_of: :customer_account
end
