class CreateAnneAuthBootstrapClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :anne_auth_bootstrap_claims do |t|
      t.string :purpose, null: false
      t.string :account_class_name
      t.bigint :account_id
      t.string :last_delivery_status
      t.datetime :completed_at

      t.timestamps
    end

    add_index :anne_auth_bootstrap_claims, :purpose, unique: true, name: "idx_anne_auth_bootstrap_claims_on_purpose"
    add_index :anne_auth_bootstrap_claims, [ :account_class_name, :account_id ], name: "idx_anne_auth_bootstrap_claims_on_account"
  end
end
