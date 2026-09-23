class CreateAnnesIntakeAnswerRelations < ActiveRecord::Migration[8.1]
  def change
    add_index :annes_intake_answers, [ :id, :field_id, :value_type ], unique: true, name: "intake_answer_identity"
    add_index :annes_intake_field_options, [ :id, :field_id ], unique: true, name: "intake_option_identity"
    create_table :annes_intake_answer_options do |t|
      t.bigint :answer_id, null: false
      t.bigint :field_id, null: false
      t.string :value_type, null: false
      t.bigint :field_option_id, null: false
      t.timestamps
    end
    add_index :annes_intake_answer_options, [ :answer_id, :field_option_id ], unique: true, name: "intake_answer_option"
    add_index :annes_intake_answer_options, [ :field_option_id, :field_id ], name: "intake_selected_option"
    add_index :annes_intake_answer_options, :answer_id, unique: true, where: "value_type = 'single_choice'", name: "intake_single_selection"
    add_foreign_key :annes_intake_answer_options, :annes_intake_answers,
      column: [ :answer_id, :field_id, :value_type ], primary_key: [ :id, :field_id, :value_type ], name: "intake_selection_answer_fk"
    add_foreign_key :annes_intake_answer_options, :annes_intake_field_options,
      column: [ :field_option_id, :field_id ], primary_key: [ :id, :field_id ], name: "intake_selection_option_fk"
    add_check_constraint :annes_intake_answer_options, "value_type IN ('single_choice','multiple_choice')", name: "intake_selection_type"

    create_table :annes_intake_answer_attachments do |t|
      t.bigint :answer_id, null: false
      t.bigint :field_id, null: false
      t.string :value_type, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :annes_intake_answer_attachments, [ :answer_id, :position ], unique: true, name: "intake_attachment_position"
    add_foreign_key :annes_intake_answer_attachments, :annes_intake_answers,
      column: [ :answer_id, :field_id, :value_type ], primary_key: [ :id, :field_id, :value_type ], name: "intake_attachment_answer_fk"
    add_check_constraint :annes_intake_answer_attachments, "value_type = 'attachment' AND position >= 0", name: "intake_attachment_type"
  end
end
