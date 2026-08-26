ActiveRecord::Schema[8.1].define(version: 0) do
  create_table "accounts", force: :cascade do |t|
    t.string "email", null: false
    t.timestamps
  end

  create_table "annes_access_roles", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "system", default: false, null: false
    t.timestamps
    t.index [ "key" ], name: "index_annes_access_roles_on_key", unique: true
  end

  create_table "annes_access_permissions", force: :cascade do |t|
    t.string "key", null: false
    t.string "resource", null: false
    t.string "action", null: false
    t.text "description"
    t.timestamps
    t.index [ "key" ], name: "index_annes_access_permissions_on_key", unique: true
    t.index [ "resource", "action" ], name: "index_annes_access_permissions_on_resource_and_action", unique: true
  end

  create_table "annes_access_role_permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "permission_id", null: false
    t.timestamps
    t.index [ "permission_id" ], name: "index_annes_access_role_permissions_on_permission_id"
    t.index [ "role_id", "permission_id" ], name: "idx_on_role_id_permission_id_annes_access", unique: true
    t.index [ "role_id" ], name: "index_annes_access_role_permissions_on_role_id"
  end

  create_table "annes_access_assignments", force: :cascade do |t|
    t.string "principal_type", null: false
    t.bigint "principal_id", null: false
    t.bigint "role_id", null: false
    t.timestamps
    t.index [ "principal_type", "principal_id", "role_id" ], name: "index_annes_access_assignments_on_principal_and_role", unique: true
    t.index [ "principal_type", "principal_id" ], name: "index_annes_access_assignments_on_principal"
    t.index [ "role_id" ], name: "index_annes_access_assignments_on_role_id"
  end

  add_foreign_key "annes_access_role_permissions", "annes_access_roles", column: "role_id"
  add_foreign_key "annes_access_role_permissions", "annes_access_permissions", column: "permission_id"
  add_foreign_key "annes_access_assignments", "annes_access_roles", column: "role_id"
end
