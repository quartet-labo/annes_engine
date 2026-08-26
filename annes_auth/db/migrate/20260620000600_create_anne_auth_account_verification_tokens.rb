class CreateAnneAuthAccountVerificationTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :account_verification_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :account_verification_tokens, :token_digest, unique: true
    add_index :account_verification_tokens, :expires_at
    add_index :account_verification_tokens, :used_at
  end
end
