ActiveRecord::Schema[8.1].define(version: 0) do
  create_table "customers", force: :cascade do |t|
    t.string "company_name"
    t.string "contact_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.text "memo"
    t.timestamps
    t.index [ "contact_name" ]
    t.index [ "email" ]
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "project_number", null: false
    t.string "status", default: "received", null: false
    t.timestamps
    t.index [ "customer_id" ]
  end
end
