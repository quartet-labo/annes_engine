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

ActiveRecord::Schema[8.1].define(version: 2026_07_13_014137) do
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

  add_foreign_key "account_identities", "accounts"
  add_foreign_key "account_password_reset_tokens", "accounts"
  add_foreign_key "account_sessions", "accounts"
  add_foreign_key "account_verification_tokens", "accounts"
  add_foreign_key "anne_access_assignments", "anne_access_roles", column: "role_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_permissions", column: "permission_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_roles", column: "role_id"
end
