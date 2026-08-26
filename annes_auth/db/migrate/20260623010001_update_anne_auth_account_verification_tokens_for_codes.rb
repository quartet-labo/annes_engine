class UpdateAnneAuthAccountVerificationTokensForCodes < ActiveRecord::Migration[8.1]
  def up
    add_column :account_verification_tokens, :attempt_count, :integer, null: false, default: 0
    add_column :account_verification_tokens, :last_attempted_at, :datetime

    remove_index :account_verification_tokens, name: "index_account_verification_tokens_on_token_digest"
    add_index :account_verification_tokens, :token_digest
    add_index :account_verification_tokens,
      [ :account_id, :token_digest ],
      name: "idx_account_verification_tokens_on_account_and_digest"
    add_index :account_verification_tokens,
      [ :account_id, :used_at, :expires_at ],
      name: "idx_account_verification_tokens_on_account_active_window"
  end

  def down
    remove_index :account_verification_tokens, name: "idx_account_verification_tokens_on_account_active_window"
    remove_index :account_verification_tokens, name: "idx_account_verification_tokens_on_account_and_digest"
    remove_index :account_verification_tokens, name: "index_account_verification_tokens_on_token_digest"
    add_index :account_verification_tokens, :token_digest, unique: true

    remove_column :account_verification_tokens, :last_attempted_at
    remove_column :account_verification_tokens, :attempt_count
  end
end
