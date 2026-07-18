class CustomerAccountInvitationToken < AnneAuth::AccountInvitationToken
  belongs_to :customer_account,
    class_name: "CustomerAccount",
    foreign_key: :customer_account_id,
    inverse_of: :customer_account_invitation_tokens
end
