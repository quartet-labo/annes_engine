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

ActiveRecord::Schema[8.1].define(version: 2026_07_13_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
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

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
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
    t.index ["name_kana"], name: "index_customers_on_name_kana"
    t.index ["phone"], name: "index_customers_on_phone"
  end

  create_table "reservation_resources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "capacity", default: 1, null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.text "memo"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_reservation_resources_on_active"
    t.index ["kind"], name: "index_reservation_resources_on_kind"
    t.index ["name"], name: "index_reservation_resources_on_name"
    t.check_constraint "capacity >= 1", name: "reservation_resources_capacity_positive"
    t.check_constraint "kind::text = ANY (ARRAY['facility'::character varying::text, 'room'::character varying::text, 'equipment'::character varying::text, 'staff'::character varying::text, 'other'::character varying::text])", name: "reservation_resources_kind_known"
  end

  create_table "reservations", force: :cascade do |t|
    t.datetime "canceled_at"
    t.bigint "canceled_by_id"
    t.text "cancellation_reason"
    t.string "channel", default: "other", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.datetime "ends_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "memo"
    t.integer "party_size", default: 1, null: false
    t.string "reservation_number", null: false
    t.bigint "reservation_resource_id", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.index ["canceled_by_id"], name: "index_reservations_on_canceled_by_id"
    t.index ["customer_id", "starts_at"], name: "index_reservations_on_customer_id_and_starts_at"
    t.index ["customer_id"], name: "index_reservations_on_customer_id"
    t.index ["ends_at"], name: "index_reservations_on_ends_at"
    t.index ["reservation_number"], name: "index_reservations_on_reservation_number", unique: true
    t.index ["reservation_resource_id", "starts_at"], name: "index_reservations_on_reservation_resource_id_and_starts_at"
    t.index ["reservation_resource_id"], name: "index_reservations_on_reservation_resource_id"
    t.index ["status", "starts_at"], name: "index_reservations_on_status_and_starts_at"
    t.check_constraint "((starts_at AT TIME ZONE 'UTC'::text) AT TIME ZONE 'Asia/Tokyo'::text)::date = ((ends_at AT TIME ZONE 'UTC'::text) AT TIME ZONE 'Asia/Tokyo'::text)::date", name: "reservations_same_tokyo_business_day"
    t.check_constraint "channel::text = ANY (ARRAY['phone'::character varying::text, 'email'::character varying::text, 'counter'::character varying::text, 'web'::character varying::text, 'other'::character varying::text])", name: "reservations_channel_known"
    t.check_constraint "ends_at > starts_at", name: "reservations_ends_after_start"
    t.check_constraint "party_size >= 1", name: "reservations_party_size_positive"
    t.check_constraint "status::text = 'canceled'::text AND canceled_at IS NOT NULL AND canceled_by_id IS NOT NULL OR status::text <> 'canceled'::text AND canceled_at IS NULL AND canceled_by_id IS NULL AND cancellation_reason IS NULL", name: "reservations_cancellation_metadata_consistent"
    t.check_constraint "status::text = ANY (ARRAY['provisional'::character varying::text, 'confirmed'::character varying::text, 'completed'::character varying::text, 'canceled'::character varying::text, 'no_show'::character varying::text])", name: "reservations_status_known"
    t.exclusion_constraint "reservation_resource_id WITH =, tsrange(starts_at, ends_at, '[)'::text) WITH &&", where: "(status)::text = ANY (ARRAY[('provisional'::character varying)::text, ('confirmed'::character varying)::text])", using: :gist, name: "reservations_no_blocking_time_overlap"
  end

  add_foreign_key "account_identities", "accounts"
  add_foreign_key "account_password_reset_tokens", "accounts"
  add_foreign_key "account_sessions", "accounts"
  add_foreign_key "account_verification_tokens", "accounts"
  add_foreign_key "anne_access_assignments", "anne_access_roles", column: "role_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_permissions", column: "permission_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_roles", column: "role_id"
  add_foreign_key "reservations", "accounts", column: "canceled_by_id"
  add_foreign_key "reservations", "customers"
  add_foreign_key "reservations", "reservation_resources"
end
