class CreateAnnesIntakeFlowRules < ActiveRecord::Migration[8.0]
  def change
    create_table :annes_intake_condition_groups do |t|
      t.references :step, null: false, foreign_key: {to_table: :annes_intake_steps}
      t.timestamps
    end
    create_table :annes_intake_conditions do |t|
      t.references :condition_group, null: false, foreign_key: {to_table: :annes_intake_condition_groups}
      t.references :source_step, null: false, foreign_key: {to_table: :annes_intake_steps}
      t.references :field, null: false, foreign_key: {to_table: :annes_intake_fields}
      t.string :operator, null: false
      t.string :expected_value, null: false
      t.timestamps
    end
    create_table :annes_intake_value_mappings do |t|
      t.references :step, null: false, foreign_key: {to_table: :annes_intake_steps}
      t.references :source_step, null: false, foreign_key: {to_table: :annes_intake_steps}
      t.references :source_field, null: false, foreign_key: {to_table: :annes_intake_fields}
      t.references :target_field, null: false, foreign_key: {to_table: :annes_intake_fields}
      t.timestamps
    end
    add_index :annes_intake_value_mappings, [:step_id, :target_field_id], unique: true, name: :idx_intake_flow_mapping_destination
  end
end
