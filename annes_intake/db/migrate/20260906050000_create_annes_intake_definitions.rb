class CreateAnnesIntakeDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_intake_forms do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :annes_intake_forms, :key, unique: true
    add_check_constraint :annes_intake_forms, "key ~ '^[a-z][a-z0-9_]{0,63}$'", name: "intake_form_key"

    create_table :annes_intake_form_versions do |t|
      t.references :form, null: false, foreign_key: { to_table: :annes_intake_forms }
      t.integer :number, null: false
      t.string :status, null: false, default: "draft"
      t.string :title, null: false
      t.text :description
      t.string :submit_label, null: false, default: "送信"
      t.text :completion_message
      t.datetime :published_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :annes_intake_form_versions, [ :form_id, :number ], unique: true, name: "intake_version_number"
    %w[draft published].each do |status|
      add_index :annes_intake_form_versions, :form_id, unique: true, where: "status = '#{status}'", name: "intake_one_#{status}"
    end
    add_check_constraint :annes_intake_form_versions, "status IN ('draft', 'published', 'retired') AND number > 0", name: "intake_version_state"

    create_table :annes_intake_fields do |t|
      t.references :form_version, null: false, foreign_key: { to_table: :annes_intake_form_versions }
      t.string :key, null: false
      t.string :value_type, null: false, default: "text"
      t.string :widget, null: false, default: "text"
      t.string :label, null: false
      t.string :placeholder
      t.text :help_text
      t.boolean :required, null: false, default: false
      t.integer :position, null: false, default: 0
      t.string :normalizer_key
      t.string :format_key
      t.integer :min_length
      t.integer :max_length
      t.decimal :min_numeric, precision: 25, scale: 6
      t.decimal :max_numeric, precision: 25, scale: 6
      t.date :min_date
      t.date :max_date
      t.datetime :min_datetime
      t.datetime :max_datetime
      t.integer :min_selections
      t.integer :max_selections
      t.boolean :must_be_true, null: false, default: false
      t.integer :max_files
      t.bigint :max_file_bytes
      t.timestamps
    end
    add_index :annes_intake_fields, [ :form_version_id, :key ], unique: true, name: "intake_field_key"
    add_check_constraint :annes_intake_fields, "key ~ '^[a-z][a-z0-9_]{0,63}$'", name: "intake_field_key_format"
    add_check_constraint :annes_intake_fields, "value_type IN ('text','integer','decimal','boolean','date','datetime','single_choice','multiple_choice','attachment')", name: "intake_field_type"
    %w[length numeric date datetime selections].each do |kind|
      add_check_constraint :annes_intake_fields, "min_#{kind} <= max_#{kind}", name: "intake_#{kind}_bounds"
    end
    %w[min_length max_length min_selections max_selections position].each do |column|
      add_check_constraint :annes_intake_fields, "#{column} >= 0", name: "intake_#{column}_nonnegative"
    end
    %w[max_files max_file_bytes].each do |column|
      add_check_constraint :annes_intake_fields, "#{column} > 0", name: "intake_#{column}_positive"
    end

    create_table :annes_intake_field_options do |t|
      t.references :field, null: false, foreign_key: { to_table: :annes_intake_fields }
      t.string :value, null: false
      t.string :label, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :annes_intake_field_options, [ :field_id, :value ], unique: true, name: "intake_option_value"
    add_check_constraint :annes_intake_field_options, "position >= 0", name: "intake_option_position"

    create_table :annes_intake_field_file_types do |t|
      t.references :field, null: false, foreign_key: { to_table: :annes_intake_fields }
      t.string :extension, null: false
      t.string :content_type
      t.timestamps
    end
    add_index :annes_intake_field_file_types, [ :field_id, :extension ], unique: true, name: "intake_file_extension"
    add_check_constraint :annes_intake_field_file_types, "extension ~ '^\\.[a-z0-9]+$'", name: "intake_extension_format"
  end
end
