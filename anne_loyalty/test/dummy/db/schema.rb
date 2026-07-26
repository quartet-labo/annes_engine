ActiveRecord::Schema[8.1].define(version: 0) do
  create_table "accounts", force: :cascade do |t|
    t.string "email", null: false
    t.timestamps
  end

  create_table "anne_loyalty_loyalty_programs", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "point_name", null: false
    t.integer "earn_unit_amount_cents", null: false
    t.integer "earn_points_per_unit", null: false
    t.integer "default_expiration_months", null: false
    t.boolean "active", default: true, null: false
    t.timestamps
    t.index [ "code" ], name: "index_anne_loyalty_loyalty_programs_on_code", unique: true
    t.check_constraint "earn_unit_amount_cents > 0 AND earn_points_per_unit > 0 AND default_expiration_months > 0", name: "anne_loyalty_programs_positive_earn_settings"
  end

  create_table "anne_loyalty_loyalty_locations", force: :cascade do |t|
    t.bigint "loyalty_program_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "time_zone", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "metadata", default: {}, null: false
    t.timestamps
    t.index [ "active" ], name: "index_anne_loyalty_loyalty_locations_on_active"
    t.index [ "loyalty_program_id", "code" ], name: "index_loyalty_locations_on_program_and_code", unique: true
  end

  create_table "anne_loyalty_loyalty_members", force: :cascade do |t|
    t.bigint "loyalty_program_id", null: false
    t.string "member_key", null: false
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.integer "cached_balance", default: 0, null: false
    t.integer "lifetime_earned_points", default: 0, null: false
    t.string "tier_key"
    t.boolean "active", default: true, null: false
    t.timestamps
    t.index [ "loyalty_program_id", "member_key" ], name: "index_loyalty_members_on_program_and_member_key", unique: true
    t.index [ "loyalty_program_id", "owner_type", "owner_id" ], name: "index_loyalty_members_on_program_and_owner", unique: true
    t.index [ "owner_type", "owner_id" ], name: "index_loyalty_members_on_owner"
    t.check_constraint "cached_balance >= 0 AND lifetime_earned_points >= 0", name: "anne_loyalty_members_non_negative_balances"
  end

  create_table "anne_loyalty_loyalty_ledger_entries", force: :cascade do |t|
    t.bigint "loyalty_member_id", null: false
    t.bigint "loyalty_location_id"
    t.string "entry_type", null: false
    t.integer "points_delta", null: false
    t.string "source_type"
    t.string "source_key"
    t.datetime "occurred_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.timestamps
    t.index [ "loyalty_location_id", "occurred_at" ], name: "index_loyalty_ledger_entries_on_location_and_time"
    t.index [ "loyalty_member_id", "occurred_at" ], name: "index_loyalty_ledger_entries_on_member_and_time"
    t.index [ "loyalty_member_id", "source_type", "source_key" ], name: "index_loyalty_ledger_entries_on_idempotency_key", unique: true, where: "((source_type IS NOT NULL) AND (source_key IS NOT NULL))"
    t.check_constraint "entry_type::text = ANY (ARRAY['earn'::character varying, 'redeem'::character varying, 'expire'::character varying, 'adjust'::character varying, 'reverse'::character varying]::text[])", name: "anne_loyalty_ledger_entries_known_type"
    t.check_constraint "points_delta <> 0", name: "anne_loyalty_ledger_entries_non_zero_delta"
    t.check_constraint "source_type IS NULL AND source_key IS NULL OR source_type IS NOT NULL AND source_key IS NOT NULL", name: "anne_loyalty_ledger_entries_source_pair"
  end

  create_table "anne_loyalty_loyalty_point_lots", force: :cascade do |t|
    t.bigint "loyalty_member_id", null: false
    t.integer "original_points", null: false
    t.integer "remaining_points", null: false
    t.date "expires_on", null: false
    t.string "status", default: "open", null: false
    t.timestamps
    t.index [ "loyalty_member_id", "expires_on" ], name: "index_loyalty_point_lots_on_member_and_expiry"
    t.index [ "loyalty_member_id", "status" ], name: "index_loyalty_point_lots_on_member_and_status"
    t.check_constraint "original_points > 0 AND remaining_points >= 0 AND remaining_points <= original_points", name: "anne_loyalty_point_lots_remaining_range"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'consumed'::character varying, 'expired'::character varying, 'voided'::character varying]::text[])", name: "anne_loyalty_point_lots_known_status"
  end

  add_foreign_key "anne_loyalty_loyalty_locations", "anne_loyalty_loyalty_programs", column: "loyalty_program_id"
  add_foreign_key "anne_loyalty_loyalty_members", "anne_loyalty_loyalty_programs", column: "loyalty_program_id"
  add_foreign_key "anne_loyalty_loyalty_ledger_entries", "anne_loyalty_loyalty_members", column: "loyalty_member_id"
  add_foreign_key "anne_loyalty_loyalty_ledger_entries", "anne_loyalty_loyalty_locations", column: "loyalty_location_id"
  add_foreign_key "anne_loyalty_loyalty_point_lots", "anne_loyalty_loyalty_members", column: "loyalty_member_id"
end
