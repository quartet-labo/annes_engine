class CreateAnnesIntakeAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_intake_step_responses do |t|
      t.references :form_version, null: false, foreign_key: { to_table: :annes_intake_form_versions }
      t.uuid :receipt_id, null: false
      t.uuid :request_key, null: false
      t.string :payload_digest, null: false, limit: 64
      t.datetime :received_at, null: false
      t.timestamps
    end
    add_index :annes_intake_step_responses, :receipt_id, unique: true
    add_index :annes_intake_step_responses, [ :form_version_id, :request_key ], unique: true, name: "intake_request_key"
    add_index :annes_intake_step_responses, [ :form_version_id, :received_at, :id ], name: "intake_received"
    add_index :annes_intake_step_responses, [ :id, :form_version_id ], unique: true, name: "intake_step_response_version"
    add_index :annes_intake_fields, [ :id, :form_version_id, :value_type ], unique: true, name: "intake_field_version_type"

    create_table :annes_intake_answers do |t|
      t.bigint :step_response_id, null: false
      t.bigint :field_id, null: false
      t.bigint :form_version_id, null: false
      t.string :value_type, null: false
      t.text :text_value
      t.bigint :integer_value
      t.decimal :decimal_value, precision: 25, scale: 6
      t.boolean :boolean_value
      t.date :date_value
      t.datetime :datetime_value
      t.timestamps
    end
    add_index :annes_intake_answers, [ :step_response_id, :field_id ], unique: true, name: "intake_answer_field"
    add_index :annes_intake_answers, [ :field_id, :form_version_id, :value_type ], name: "intake_answer_definition"
    add_foreign_key :annes_intake_answers, :annes_intake_step_responses,
      column: [ :step_response_id, :form_version_id ], primary_key: [ :id, :form_version_id ], name: "intake_answer_step_response_fk"
    add_foreign_key :annes_intake_answers, :annes_intake_fields,
      column: [ :field_id, :form_version_id, :value_type ], primary_key: [ :id, :form_version_id, :value_type ], name: "intake_answer_definition_fk"
    types = %w[text integer decimal boolean date datetime]
    clauses = types.map do |type|
      values = types.map { |other| "#{other}_value IS #{other == type ? 'NOT ' : ''}NULL" }.join(" AND ")
      "(value_type = '#{type}' AND #{values})"
    end
    clauses << "(value_type IN ('single_choice','multiple_choice','attachment') AND #{types.map { |type| "#{type}_value IS NULL" }.join(' AND ')})"
    add_check_constraint :annes_intake_answers, clauses.join(" OR "), name: "intake_typed_value"
  end
end
