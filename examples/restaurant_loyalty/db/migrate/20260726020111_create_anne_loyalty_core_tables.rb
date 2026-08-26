class CreateAnneLoyaltyCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :anne_loyalty_loyalty_programs do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :point_name, null: false
      t.integer :earn_unit_amount_cents, null: false
      t.integer :earn_points_per_unit, null: false
      t.integer :default_expiration_months, null: false
      t.boolean :active, null: false, default: true

      t.timestamps

      t.index :code, unique: true
    end

    add_check_constraint :anne_loyalty_loyalty_programs,
      "earn_unit_amount_cents > 0 AND earn_points_per_unit > 0 AND default_expiration_months > 0",
      name: "anne_loyalty_programs_positive_earn_settings"

    create_table :anne_loyalty_loyalty_locations do |t|
      t.references :loyalty_program, null: false, foreign_key: { to_table: :anne_loyalty_loyalty_programs }, index: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :time_zone, null: false
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps

      t.index [ :loyalty_program_id, :code ], unique: true, name: "index_loyalty_locations_on_program_and_code"
      t.index :active
    end

    create_table :anne_loyalty_loyalty_members do |t|
      t.references :loyalty_program, null: false, foreign_key: { to_table: :anne_loyalty_loyalty_programs }, index: false
      t.string :member_key, null: false
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.integer :cached_balance, null: false, default: 0
      t.integer :lifetime_earned_points, null: false, default: 0
      t.string :tier_key
      t.boolean :active, null: false, default: true

      t.timestamps

      t.index [ :owner_type, :owner_id ], name: "index_loyalty_members_on_owner"
      t.index [ :loyalty_program_id, :owner_type, :owner_id ],
        unique: true,
        name: "index_loyalty_members_on_program_and_owner"
      t.index [ :loyalty_program_id, :member_key ],
        unique: true,
        name: "index_loyalty_members_on_program_and_member_key"
    end

    add_check_constraint :anne_loyalty_loyalty_members,
      "cached_balance >= 0 AND lifetime_earned_points >= 0",
      name: "anne_loyalty_members_non_negative_balances"

    create_table :anne_loyalty_loyalty_ledger_entries do |t|
      t.references :loyalty_member, null: false, foreign_key: { to_table: :anne_loyalty_loyalty_members }, index: false
      t.references :loyalty_location, null: true, foreign_key: { to_table: :anne_loyalty_loyalty_locations }, index: false
      t.string :entry_type, null: false
      t.integer :points_delta, null: false
      t.string :source_type
      t.string :source_key
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps

      t.index [ :loyalty_member_id, :occurred_at ], name: "index_loyalty_ledger_entries_on_member_and_time"
      t.index [ :loyalty_location_id, :occurred_at ], name: "index_loyalty_ledger_entries_on_location_and_time"
      t.index [ :loyalty_member_id, :source_type, :source_key ],
        unique: true,
        where: "source_type IS NOT NULL AND source_key IS NOT NULL",
        name: "index_loyalty_ledger_entries_on_idempotency_key"
    end

    add_check_constraint :anne_loyalty_loyalty_ledger_entries,
      "entry_type IN ('earn', 'redeem', 'expire', 'adjust', 'reverse')",
      name: "anne_loyalty_ledger_entries_known_type"
    add_check_constraint :anne_loyalty_loyalty_ledger_entries,
      "points_delta <> 0",
      name: "anne_loyalty_ledger_entries_non_zero_delta"
    add_check_constraint :anne_loyalty_loyalty_ledger_entries,
      "(source_type IS NULL AND source_key IS NULL) OR (source_type IS NOT NULL AND source_key IS NOT NULL)",
      name: "anne_loyalty_ledger_entries_source_pair"

    create_table :anne_loyalty_loyalty_point_lots do |t|
      t.references :loyalty_member, null: false, foreign_key: { to_table: :anne_loyalty_loyalty_members }, index: false
      t.integer :original_points, null: false
      t.integer :remaining_points, null: false
      t.date :expires_on, null: false
      t.string :status, null: false, default: "open"

      t.timestamps

      t.index [ :loyalty_member_id, :expires_on ], name: "index_loyalty_point_lots_on_member_and_expiry"
      t.index [ :loyalty_member_id, :status ], name: "index_loyalty_point_lots_on_member_and_status"
    end

    add_check_constraint :anne_loyalty_loyalty_point_lots,
      "original_points > 0 AND remaining_points >= 0 AND remaining_points <= original_points",
      name: "anne_loyalty_point_lots_remaining_range"
    add_check_constraint :anne_loyalty_loyalty_point_lots,
      "status IN ('open', 'consumed', 'expired', 'voided')",
      name: "anne_loyalty_point_lots_known_status"
  end
end
