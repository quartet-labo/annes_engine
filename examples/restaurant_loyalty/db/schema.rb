# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_26_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_identities", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider"], name: "index_account_identities_on_account_and_provider", unique: true
    t.index ["account_id"], name: "index_account_identities_on_account_id"
    t.index ["provider", "uid"], name: "index_account_identities_on_provider_and_uid", unique: true
  end

  create_table "account_password_reset_tokens", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["account_id"], name: "idx_account_password_reset_tokens_on_account_id"
    t.index ["expires_at"], name: "idx_account_password_reset_tokens_on_expires_at"
    t.index ["token_digest"], name: "idx_account_password_reset_tokens_on_digest", unique: true
    t.index ["used_at"], name: "idx_account_password_reset_tokens_on_used_at"
  end

  create_table "account_sessions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "last_used_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["account_id"], name: "index_account_sessions_on_account_id"
    t.index ["expires_at"], name: "index_account_sessions_on_expires_at"
  end

  create_table "account_verification_tokens", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_attempted_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["account_id", "token_digest"], name: "idx_account_verification_tokens_on_account_and_digest"
    t.index ["account_id", "used_at", "expires_at"], name: "idx_account_verification_tokens_on_account_active_window"
    t.index ["account_id"], name: "index_account_verification_tokens_on_account_id"
    t.index ["expires_at"], name: "index_account_verification_tokens_on_expires_at"
    t.index ["token_digest"], name: "index_account_verification_tokens_on_token_digest"
    t.index ["used_at"], name: "index_account_verification_tokens_on_used_at"
  end

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "email", null: false
    t.datetime "email_verified_at"
    t.datetime "last_sign_in_at"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["disabled_at"], name: "index_accounts_on_disabled_at"
    t.index ["email"], name: "index_accounts_on_email", unique: true
    t.index ["email_verified_at"], name: "index_accounts_on_email_verified_at"
  end

  create_table "anne_access_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "principal_id", null: false
    t.string "principal_type", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["principal_type", "principal_id", "role_id"], name: "index_anne_access_assignments_on_principal_and_role", unique: true
    t.index ["principal_type", "principal_id"], name: "index_anne_access_assignments_on_principal"
    t.index ["role_id"], name: "index_anne_access_assignments_on_role_id"
  end

  create_table "anne_access_permissions", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "resource", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_anne_access_permissions_on_key", unique: true
    t.index ["resource", "action"], name: "index_anne_access_permissions_on_resource_and_action", unique: true
  end

  create_table "anne_access_role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_anne_access_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "idx_on_role_id_permission_id_12eec61da5", unique: true
    t.index ["role_id"], name: "index_anne_access_role_permissions_on_role_id"
  end

  create_table "anne_access_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_anne_access_roles_on_key", unique: true
  end

  create_table "anne_loyalty_loyalty_ledger_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "entry_type", null: false
    t.bigint "loyalty_location_id"
    t.bigint "loyalty_member_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.integer "points_delta", null: false
    t.string "source_key"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["loyalty_location_id", "occurred_at"], name: "index_loyalty_ledger_entries_on_location_and_time"
    t.index ["loyalty_member_id", "occurred_at"], name: "index_loyalty_ledger_entries_on_member_and_time"
    t.index ["loyalty_member_id", "source_type", "source_key"], name: "index_loyalty_ledger_entries_on_idempotency_key", unique: true, where: "((source_type IS NOT NULL) AND (source_key IS NOT NULL))"
    t.check_constraint "entry_type::text = ANY (ARRAY['earn'::character varying::text, 'redeem'::character varying::text, 'expire'::character varying::text, 'adjust'::character varying::text, 'reverse'::character varying::text])", name: "anne_loyalty_ledger_entries_known_type"
    t.check_constraint "points_delta <> 0", name: "anne_loyalty_ledger_entries_non_zero_delta"
    t.check_constraint "source_type IS NULL AND source_key IS NULL OR source_type IS NOT NULL AND source_key IS NOT NULL", name: "anne_loyalty_ledger_entries_source_pair"
  end

  create_table "anne_loyalty_loyalty_locations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "loyalty_program_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "time_zone", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_anne_loyalty_loyalty_locations_on_active"
    t.index ["loyalty_program_id", "code"], name: "index_loyalty_locations_on_program_and_code", unique: true
  end

  create_table "anne_loyalty_loyalty_members", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "cached_balance", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "lifetime_earned_points", default: 0, null: false
    t.bigint "loyalty_program_id", null: false
    t.string "member_key", null: false
    t.bigint "owner_id", null: false
    t.string "owner_type", null: false
    t.string "tier_key"
    t.datetime "updated_at", null: false
    t.index ["loyalty_program_id", "member_key"], name: "index_loyalty_members_on_program_and_member_key", unique: true
    t.index ["loyalty_program_id", "owner_type", "owner_id"], name: "index_loyalty_members_on_program_and_owner", unique: true
    t.index ["owner_type", "owner_id"], name: "index_loyalty_members_on_owner"
    t.check_constraint "cached_balance >= 0 AND lifetime_earned_points >= 0", name: "anne_loyalty_members_non_negative_balances"
  end

  create_table "anne_loyalty_loyalty_point_lots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expires_on", null: false
    t.bigint "loyalty_member_id", null: false
    t.integer "original_points", null: false
    t.integer "remaining_points", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["loyalty_member_id", "expires_on"], name: "index_loyalty_point_lots_on_member_and_expiry"
    t.index ["loyalty_member_id", "status"], name: "index_loyalty_point_lots_on_member_and_status"
    t.check_constraint "original_points > 0 AND remaining_points >= 0 AND remaining_points <= original_points", name: "anne_loyalty_point_lots_remaining_range"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'consumed'::character varying::text, 'expired'::character varying::text, 'voided'::character varying::text])", name: "anne_loyalty_point_lots_known_status"
  end

  create_table "anne_loyalty_loyalty_programs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "default_expiration_months", null: false
    t.integer "earn_points_per_unit", null: false
    t.integer "earn_unit_amount_cents", null: false
    t.string "name", null: false
    t.string "point_name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_anne_loyalty_loyalty_programs_on_code", unique: true
    t.check_constraint "earn_unit_amount_cents > 0 AND earn_points_per_unit > 0 AND default_expiration_months > 0", name: "anne_loyalty_programs_positive_earn_settings"
  end

  create_table "anne_loyalty_loyalty_redemptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "issued_at", null: false
    t.bigint "loyalty_member_id", null: false
    t.bigint "loyalty_reward_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "redeemed_at"
    t.bigint "redeemed_loyalty_location_id"
    t.string "status", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["loyalty_member_id", "status"], name: "index_loyalty_redemptions_on_member_and_status"
    t.index ["loyalty_reward_id", "status"], name: "index_loyalty_redemptions_on_reward_and_status"
    t.index ["token_digest"], name: "index_loyalty_redemptions_on_token_digest", unique: true
    t.check_constraint "expires_at > issued_at", name: "anne_loyalty_redemptions_expiry_after_issue"
    t.check_constraint "redeemed_at IS NULL OR redeemed_at >= issued_at", name: "anne_loyalty_redemptions_redeemed_after_issue"
    t.check_constraint "status::text = ANY (ARRAY['issued'::character varying::text, 'redeemed'::character varying::text, 'expired'::character varying::text, 'canceled'::character varying::text])", name: "anne_loyalty_redemptions_known_status"
  end

  create_table "anne_loyalty_loyalty_rewards", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "loyalty_program_id", null: false
    t.string "name", null: false
    t.integer "required_points", null: false
    t.datetime "updated_at", null: false
    t.integer "valid_minutes", null: false
    t.index ["active"], name: "index_anne_loyalty_loyalty_rewards_on_active"
    t.index ["loyalty_program_id", "code"], name: "index_loyalty_rewards_on_program_and_code", unique: true
    t.check_constraint "required_points > 0 AND valid_minutes > 0", name: "anne_loyalty_rewards_positive_settings"
  end

  create_table "annes_auth_bootstrap_claims", force: :cascade do |t|
    t.string "account_class_name"
    t.bigint "account_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "last_delivery_status"
    t.string "purpose", null: false
    t.datetime "updated_at", null: false
    t.index ["account_class_name", "account_id"], name: "idx_annes_auth_bootstrap_claims_on_account"
    t.index ["purpose"], name: "idx_annes_auth_bootstrap_claims_on_purpose", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.string "access_code_digest"
    t.boolean "active", default: true, null: false
    t.date "birthday"
    t.datetime "created_at", null: false
    t.string "customer_number", null: false
    t.string "email"
    t.text "memo"
    t.string "name", null: false
    t.string "name_kana"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_customers_on_active"
    t.index ["customer_number"], name: "index_customers_on_customer_number", unique: true
    t.index ["email"], name: "index_customers_on_email"
    t.index ["name"], name: "index_customers_on_name"
  end

  create_table "receipts", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "loyalty_location_id"
    t.text "memo"
    t.datetime "purchased_at", null: false
    t.string "receipt_number", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "purchased_at"], name: "index_receipts_on_customer_id_and_purchased_at"
    t.index ["customer_id"], name: "index_receipts_on_customer_id"
    t.index ["loyalty_location_id"], name: "index_receipts_on_loyalty_location_id"
    t.index ["receipt_number"], name: "index_receipts_on_receipt_number", unique: true
    t.check_constraint "amount_cents > 0", name: "receipts_amount_positive"
  end

  create_table "visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "loyalty_location_id"
    t.text "memo"
    t.datetime "updated_at", null: false
    t.datetime "visited_at", null: false
    t.index ["customer_id", "visited_at"], name: "index_visits_on_customer_id_and_visited_at"
    t.index ["customer_id"], name: "index_visits_on_customer_id"
    t.index ["loyalty_location_id"], name: "index_visits_on_loyalty_location_id"
  end

  add_foreign_key "account_identities", "accounts"
  add_foreign_key "account_password_reset_tokens", "accounts"
  add_foreign_key "account_sessions", "accounts"
  add_foreign_key "account_verification_tokens", "accounts"
  add_foreign_key "anne_access_assignments", "anne_access_roles", column: "role_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_permissions", column: "permission_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_roles", column: "role_id"
  add_foreign_key "anne_loyalty_loyalty_ledger_entries", "anne_loyalty_loyalty_locations", column: "loyalty_location_id"
  add_foreign_key "anne_loyalty_loyalty_ledger_entries", "anne_loyalty_loyalty_members", column: "loyalty_member_id"
  add_foreign_key "anne_loyalty_loyalty_locations", "anne_loyalty_loyalty_programs", column: "loyalty_program_id"
  add_foreign_key "anne_loyalty_loyalty_members", "anne_loyalty_loyalty_programs", column: "loyalty_program_id"
  add_foreign_key "anne_loyalty_loyalty_point_lots", "anne_loyalty_loyalty_members", column: "loyalty_member_id"
  add_foreign_key "anne_loyalty_loyalty_redemptions", "anne_loyalty_loyalty_locations", column: "redeemed_loyalty_location_id"
  add_foreign_key "anne_loyalty_loyalty_redemptions", "anne_loyalty_loyalty_members", column: "loyalty_member_id"
  add_foreign_key "anne_loyalty_loyalty_redemptions", "anne_loyalty_loyalty_rewards", column: "loyalty_reward_id"
  add_foreign_key "anne_loyalty_loyalty_rewards", "anne_loyalty_loyalty_programs", column: "loyalty_program_id"
  add_foreign_key "receipts", "anne_loyalty_loyalty_locations", column: "loyalty_location_id"
  add_foreign_key "receipts", "customers"
  add_foreign_key "visits", "anne_loyalty_loyalty_locations", column: "loyalty_location_id"
  add_foreign_key "visits", "customers"
end
