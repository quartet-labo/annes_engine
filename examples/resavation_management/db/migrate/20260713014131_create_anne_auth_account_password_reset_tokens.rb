class CreateAnneAuthAccountPasswordResetTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :account_password_reset_tokens do |t|
      t.references :account, null: false, foreign_key: true, index: { name: "idx_account_password_reset_tokens_on_account_id" }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :account_password_reset_tokens, :token_digest, unique: true, name: "idx_account_password_reset_tokens_on_digest"
    add_index :account_password_reset_tokens, :expires_at, name: "idx_account_password_reset_tokens_on_expires_at"
    add_index :account_password_reset_tokens, :used_at, name: "idx_account_password_reset_tokens_on_used_at"
  end
end
