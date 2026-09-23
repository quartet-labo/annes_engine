class CreateAnnesIntakeFlowDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_intake_flows do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :annes_intake_flows, :key, unique: true
    add_check_constraint :annes_intake_flows, "key ~ '^[a-z][a-z0-9_]{0,63}$'", name: "intake_flow_key"
    create_table :annes_intake_flow_versions do |t|
      t.references :flow, null: false, foreign_key: { to_table: :annes_intake_flows }
      t.integer :number, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.integer :lock_version, null: false, default: 0
      t.datetime :published_at
      t.timestamps
    end
    add_index :annes_intake_flow_versions, [:flow_id, :number], unique: true
    %w[draft published].each do |state|
      add_index :annes_intake_flow_versions, :flow_id, unique: true, where: "status = '#{state}'", name: "intake_flow_one_#{state}"
    end
    add_check_constraint :annes_intake_flow_versions, "number > 0 AND status IN ('draft','published','retired')", name: "intake_flow_version_state"
    create_table :annes_intake_steps do |t|
      t.references :flow_version, null: false, foreign_key: { to_table: :annes_intake_flow_versions }
      t.references :form_version, null: false, foreign_key: { to_table: :annes_intake_form_versions }
      t.string :key, null: false
      t.string :title, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :annes_intake_steps, [:flow_version_id, :key], unique: true
    add_index :annes_intake_steps, [:flow_version_id, :position], unique: true
    add_index :annes_intake_steps, [:id, :flow_version_id, :form_version_id], unique: true, name: "intake_step_identity"
    add_check_constraint :annes_intake_steps, "position >= 0 AND key ~ '^[a-z][a-z0-9_]{0,63}$'", name: "intake_step_key"
  end
end
