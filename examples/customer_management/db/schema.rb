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

ActiveRecord::Schema[8.1].define(version: 2026_07_09_022000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "email", null: false
    t.datetime "email_verified_at"
    t.datetime "last_sign_in_at"
    t.string "name"
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
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

  create_table "customer_contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "department"
    t.string "email"
    t.text "memo"
    t.bigint "person_id", null: false
    t.string "phone"
    t.boolean "primary", default: false, null: false
    t.string "role", default: "primary", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_contacts_on_customer_id"
    t.index ["person_id"], name: "index_customer_contacts_on_person_id"
    t.index ["primary"], name: "index_customer_contacts_on_primary"
    t.index ["role"], name: "index_customer_contacts_on_role"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "customer_number", null: false
    t.string "kind", null: false
    t.text "memo"
    t.bigint "organization_id"
    t.bigint "person_id"
    t.string "source"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_number"], name: "index_customers_on_customer_number", unique: true
    t.index ["kind"], name: "index_customers_on_kind"
    t.index ["organization_id"], name: "index_customers_on_organization_id"
    t.index ["person_id"], name: "index_customers_on_person_id"
    t.index ["status"], name: "index_customers_on_status"
    t.check_constraint "kind::text = 'person'::text AND person_id IS NOT NULL AND organization_id IS NULL OR kind::text = 'organization'::text AND organization_id IS NOT NULL AND person_id IS NULL", name: "customers_kind_target_check"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "memo"
    t.string "name", null: false
    t.string "name_kana"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["name"], name: "index_organizations_on_name"
  end

  create_table "persons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.text "memo"
    t.string "name", null: false
    t.string "name_kana"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_persons_on_email"
    t.index ["name"], name: "index_persons_on_name"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.date "due_on"
    t.text "memo"
    t.string "name", null: false
    t.string "project_number", null: false
    t.string "status", default: "lead", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_projects_on_customer_id"
    t.index ["due_on"], name: "index_projects_on_due_on"
    t.index ["project_number"], name: "index_projects_on_project_number", unique: true
    t.index ["status"], name: "index_projects_on_status"
  end

  add_foreign_key "account_sessions", "accounts"
  add_foreign_key "anne_access_assignments", "anne_access_roles", column: "role_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_permissions", column: "permission_id"
  add_foreign_key "anne_access_role_permissions", "anne_access_roles", column: "role_id"
  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customer_contacts", "persons"
  add_foreign_key "customers", "organizations"
  add_foreign_key "customers", "persons"
  add_foreign_key "projects", "customers"
end
