class CreateAnneAuthAccountInvitationTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :account_invitation_tokens do |t|
      t.references :account, null: false, foreign_key: true, index: { name: "idx_account_invitation_tokens_on_account_id" }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :account_invitation_tokens, :token_digest, unique: true, name: "idx_account_invitation_tokens_on_digest"
    add_index :account_invitation_tokens, :expires_at, name: "idx_account_invitation_tokens_on_expires_at"
    add_index :account_invitation_tokens, :used_at, name: "idx_account_invitation_tokens_on_used_at"
  end
end
