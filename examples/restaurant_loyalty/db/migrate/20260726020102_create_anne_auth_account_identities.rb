class CreateAnneAuthAccountIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :account_identities do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email

      t.timestamps
    end

    add_index :account_identities, [ :provider, :uid ], unique: true
    add_index :account_identities,
      [ :account_id, :provider ],
      unique: true,
      name: "index_account_identities_on_account_and_provider"
  end
end
