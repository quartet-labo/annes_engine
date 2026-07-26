ActiveRecord::Schema[8.1].define(version: 0) do
  create_table "accounts", force: :cascade do |t|
    t.string "email", null: false
    t.timestamps
  end
end
