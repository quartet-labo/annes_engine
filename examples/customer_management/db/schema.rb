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

ActiveRecord::Schema[8.1].define(version: 2026_07_01_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_sign_in_at"
    t.string "name"
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
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

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customer_contacts", "persons"
  add_foreign_key "customers", "organizations"
  add_foreign_key "customers", "persons"
  add_foreign_key "projects", "customers"
  add_foreign_key "sessions", "users"
end
