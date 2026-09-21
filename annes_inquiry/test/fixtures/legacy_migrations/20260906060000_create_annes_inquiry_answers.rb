class CreateAnnesInquiryAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_inquiry_submissions do |t|
      t.references :form_version, null: false, foreign_key: { to_table: :annes_inquiry_form_versions }
      t.uuid :receipt_id, null: false
      t.uuid :request_key, null: false
      t.string :payload_digest, null: false, limit: 64
      t.datetime :received_at, null: false
      t.timestamps
    end
    add_index :annes_inquiry_submissions, :receipt_id, unique: true
    add_index :annes_inquiry_submissions, [ :form_version_id, :request_key ], unique: true, name: "inquiry_request_key"
    add_index :annes_inquiry_submissions, [ :form_version_id, :received_at, :id ], name: "inquiry_received"
    add_index :annes_inquiry_submissions, [ :id, :form_version_id ], unique: true, name: "inquiry_submission_version"
    add_index :annes_inquiry_fields, [ :id, :form_version_id, :value_type ], unique: true, name: "inquiry_field_version_type"

    create_table :annes_inquiry_answers do |t|
      t.bigint :submission_id, null: false
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
    add_index :annes_inquiry_answers, [ :submission_id, :field_id ], unique: true, name: "inquiry_answer_field"
    add_index :annes_inquiry_answers, [ :field_id, :form_version_id, :value_type ], name: "inquiry_answer_definition"
    add_foreign_key :annes_inquiry_answers, :annes_inquiry_submissions,
      column: [ :submission_id, :form_version_id ], primary_key: [ :id, :form_version_id ], name: "inquiry_answer_submission_fk"
    add_foreign_key :annes_inquiry_answers, :annes_inquiry_fields,
      column: [ :field_id, :form_version_id, :value_type ], primary_key: [ :id, :form_version_id, :value_type ], name: "inquiry_answer_definition_fk"
    types = %w[text integer decimal boolean date datetime]
    clauses = types.map do |type|
      values = types.map { |other| "#{other}_value IS #{other == type ? 'NOT ' : ''}NULL" }.join(" AND ")
      "(value_type = '#{type}' AND #{values})"
    end
    clauses << "(value_type IN ('single_choice','multiple_choice','attachment') AND #{types.map { |type| "#{type}_value IS NULL" }.join(' AND ')})"
    add_check_constraint :annes_inquiry_answers, clauses.join(" OR "), name: "inquiry_typed_value"
  end
end
