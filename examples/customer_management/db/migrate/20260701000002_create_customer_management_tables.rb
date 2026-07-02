class CreateCustomerManagementTables < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :company_name
      t.string :contact_name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :memo

      t.timestamps
    end
    add_index :customers, :company_name
    add_index :customers, :contact_name
    add_index :customers, :email

    create_table :projects do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :project_number, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "lead"
      t.date :due_on
      t.text :memo

      t.timestamps
    end
    add_index :projects, :project_number, unique: true
    add_index :projects, :status
    add_index :projects, :due_on
  end
end
