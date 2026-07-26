class CreateRestaurantLoyaltyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :customer_number, null: false
      t.string :name, null: false
      t.string :name_kana
      t.string :email
      t.string :phone
      t.date :birthday
      t.boolean :active, null: false, default: true
      t.text :memo

      t.timestamps
    end

    add_index :customers, :customer_number, unique: true
    add_index :customers, :name
    add_index :customers, :email
    add_index :customers, :active

    create_table :receipts do |t|
      t.string :receipt_number, null: false
      t.references :customer, null: false, foreign_key: true
      t.references :loyalty_location, foreign_key: { to_table: :anne_loyalty_loyalty_locations }
      t.integer :amount_cents, null: false
      t.datetime :purchased_at, null: false
      t.text :memo

      t.timestamps
    end

    add_index :receipts, :receipt_number, unique: true
    add_index :receipts, [ :customer_id, :purchased_at ]
    add_check_constraint :receipts, "amount_cents > 0", name: "receipts_amount_positive"

    create_table :visits do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :loyalty_location, foreign_key: { to_table: :anne_loyalty_loyalty_locations }
      t.datetime :visited_at, null: false
      t.text :memo

      t.timestamps
    end

    add_index :visits, [ :customer_id, :visited_at ]
  end
end
