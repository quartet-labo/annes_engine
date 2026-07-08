ActiveRecord::Schema[8.1].define(version: 0) do
  create_table "admin_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.datetime "last_sign_in_at"
    t.timestamps
    t.index [ "email" ], unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.string "role", default: "admin", null: false
    t.datetime "last_sign_in_at"
    t.timestamps
    t.index [ "email" ], unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.timestamps
    t.index [ "user_id" ]
  end

  create_table "customer_accounts", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "email_verified_at"
    t.datetime "last_sign_in_at"
    t.datetime "disabled_at"
    t.timestamps
    t.index [ "email" ], unique: true
  end

  create_table "customer_sessions", force: :cascade do |t|
    t.bigint "customer_account_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.timestamps
    t.index [ "customer_account_id" ]
  end

  create_table "customer_account_identities", force: :cascade do |t|
    t.bigint "customer_account_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email"
    t.timestamps
    t.index [ "customer_account_id", "provider" ], unique: true, name: "idx_auth_identities_on_account_and_provider"
    t.index [ "provider", "uid" ], unique: true, name: "idx_auth_identities_on_provider_and_uid"
  end

  create_table "customer_account_verification_tokens", force: :cascade do |t|
    t.bigint "customer_account_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.integer "attempt_count", default: 0, null: false
    t.datetime "last_attempted_at"
    t.timestamps
    t.index [ "customer_account_id" ]
    t.index [ "token_digest" ]
  end

  create_table "customer_account_password_reset_tokens", force: :cascade do |t|
    t.bigint "customer_account_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.timestamps
    t.index [ "customer_account_id" ]
    t.index [ "token_digest" ], unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.string "company_name"
    t.string "contact_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.text "memo"
    t.timestamps
  end

  create_table "customer_account_memberships", force: :cascade do |t|
    t.bigint "customer_account_id", null: false
    t.bigint "customer_id", null: false
    t.string "role", default: "owner", null: false
    t.datetime "invited_at"
    t.datetime "accepted_at"
    t.timestamps
    t.index [ "customer_account_id", "customer_id" ], unique: true, name: "idx_auth_memberships_on_account_and_customer"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "project_number", null: false
    t.string "status", default: "received", null: false
    t.timestamps
  end

  create_table "customer_account_projects", force: :cascade do |t|
    t.bigint "customer_account_id", null: false
    t.bigint "project_id", null: false
    t.string "source", default: "account_created", null: false
    t.timestamps
    t.index [ "customer_account_id", "project_id" ], unique: true, name: "idx_auth_account_projects_on_account_and_project"
  end
end
