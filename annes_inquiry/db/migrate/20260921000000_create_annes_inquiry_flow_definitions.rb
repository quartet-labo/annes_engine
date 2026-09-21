class CreateAnnesInquiryFlowDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_inquiry_flows do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :annes_inquiry_flows, :key, unique: true
    add_check_constraint :annes_inquiry_flows, "key ~ '^[a-z][a-z0-9_]{0,63}$'", name: "inquiry_flow_key"
    create_table :annes_inquiry_flow_versions do |t|
      t.references :flow, null: false, foreign_key: { to_table: :annes_inquiry_flows }
      t.integer :number, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.integer :lock_version, null: false, default: 0
      t.datetime :published_at
      t.timestamps
    end
    add_index :annes_inquiry_flow_versions, [:flow_id, :number], unique: true
    %w[draft published].each do |state|
      add_index :annes_inquiry_flow_versions, :flow_id, unique: true, where: "status = '#{state}'", name: "inquiry_flow_one_#{state}"
    end
    add_check_constraint :annes_inquiry_flow_versions, "number > 0 AND status IN ('draft','published','retired')", name: "inquiry_flow_version_state"
    create_table :annes_inquiry_flow_steps do |t|
      t.references :flow_version, null: false, foreign_key: { to_table: :annes_inquiry_flow_versions }
      t.references :form_version, null: false, foreign_key: { to_table: :annes_inquiry_form_versions }
      t.string :key, null: false
      t.string :title, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :annes_inquiry_flow_steps, [:flow_version_id, :key], unique: true
    add_index :annes_inquiry_flow_steps, [:flow_version_id, :position], unique: true
    add_index :annes_inquiry_flow_steps, [:id, :flow_version_id, :form_version_id], unique: true, name: "inquiry_flow_step_identity"
    add_check_constraint :annes_inquiry_flow_steps, "position >= 0 AND key ~ '^[a-z][a-z0-9_]{0,63}$'", name: "inquiry_flow_step_key"
  end
end
