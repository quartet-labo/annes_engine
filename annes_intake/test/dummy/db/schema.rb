# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_22_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "annes_intake_answer_attachments", force: :cascade do |t|
    t.bigint "answer_id", null: false
    t.datetime "created_at", null: false
    t.bigint "field_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "value_type", null: false
    t.index ["answer_id", "position"], name: "intake_attachment_position", unique: true
    t.check_constraint "value_type::text = 'attachment'::text AND \"position\" >= 0", name: "intake_attachment_type"
  end

  create_table "annes_intake_answer_options", force: :cascade do |t|
    t.bigint "answer_id", null: false
    t.datetime "created_at", null: false
    t.bigint "field_id", null: false
    t.bigint "field_option_id", null: false
    t.datetime "updated_at", null: false
    t.string "value_type", null: false
    t.index ["answer_id", "field_option_id"], name: "intake_answer_option", unique: true
    t.index ["answer_id"], name: "intake_single_selection", unique: true, where: "((value_type)::text = 'single_choice'::text)"
    t.index ["field_option_id", "field_id"], name: "intake_selected_option"
    t.check_constraint "value_type::text = ANY (ARRAY['single_choice'::character varying::text, 'multiple_choice'::character varying::text])", name: "intake_selection_type"
  end

  create_table "annes_intake_answers", force: :cascade do |t|
    t.boolean "boolean_value"
    t.datetime "created_at", null: false
    t.date "date_value"
    t.datetime "datetime_value"
    t.decimal "decimal_value", precision: 25, scale: 6
    t.bigint "field_id", null: false
    t.bigint "form_version_id", null: false
    t.bigint "integer_value"
    t.bigint "step_response_id", null: false
    t.text "text_value"
    t.datetime "updated_at", null: false
    t.string "value_type", null: false
    t.index ["field_id", "form_version_id", "value_type"], name: "intake_answer_definition"
    t.index ["id", "field_id", "value_type"], name: "intake_answer_identity", unique: true
    t.index ["step_response_id", "field_id"], name: "intake_answer_field", unique: true
    t.check_constraint "value_type::text = 'text'::text AND text_value IS NOT NULL AND integer_value IS NULL AND decimal_value IS NULL AND boolean_value IS NULL AND date_value IS NULL AND datetime_value IS NULL OR value_type::text = 'integer'::text AND text_value IS NULL AND integer_value IS NOT NULL AND decimal_value IS NULL AND boolean_value IS NULL AND date_value IS NULL AND datetime_value IS NULL OR value_type::text = 'decimal'::text AND text_value IS NULL AND integer_value IS NULL AND decimal_value IS NOT NULL AND boolean_value IS NULL AND date_value IS NULL AND datetime_value IS NULL OR value_type::text = 'boolean'::text AND text_value IS NULL AND integer_value IS NULL AND decimal_value IS NULL AND boolean_value IS NOT NULL AND date_value IS NULL AND datetime_value IS NULL OR value_type::text = 'date'::text AND text_value IS NULL AND integer_value IS NULL AND decimal_value IS NULL AND boolean_value IS NULL AND date_value IS NOT NULL AND datetime_value IS NULL OR value_type::text = 'datetime'::text AND text_value IS NULL AND integer_value IS NULL AND decimal_value IS NULL AND boolean_value IS NULL AND date_value IS NULL AND datetime_value IS NOT NULL OR (value_type::text = ANY (ARRAY['single_choice'::character varying::text, 'multiple_choice'::character varying::text, 'attachment'::character varying::text])) AND text_value IS NULL AND integer_value IS NULL AND decimal_value IS NULL AND boolean_value IS NULL AND date_value IS NULL AND datetime_value IS NULL", name: "intake_typed_value"
  end

  create_table "annes_intake_blob_deletions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "image", default: false, null: false
    t.string "key", null: false
    t.string "service_name", null: false
    t.datetime "updated_at", null: false
    t.index ["service_name", "key"], name: "intake_blob_deletion_key", unique: true
  end

  create_table "annes_intake_condition_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "step_id", null: false
    t.datetime "updated_at", null: false
    t.index ["step_id"], name: "index_annes_intake_condition_groups_on_step_id"
  end

  create_table "annes_intake_conditions", force: :cascade do |t|
    t.bigint "condition_group_id", null: false
    t.datetime "created_at", null: false
    t.string "expected_value", null: false
    t.bigint "field_id", null: false
    t.string "operator", null: false
    t.bigint "source_step_id", null: false
    t.datetime "updated_at", null: false
    t.index ["condition_group_id"], name: "index_annes_intake_conditions_on_condition_group_id"
    t.index ["field_id"], name: "index_annes_intake_conditions_on_field_id"
    t.index ["source_step_id"], name: "index_annes_intake_conditions_on_source_step_id"
  end

  create_table "annes_intake_draft_answer_values", force: :cascade do |t|
    t.bigint "draft_answer_id", null: false
    t.integer "position", null: false
    t.text "raw_value", null: false
    t.index ["draft_answer_id", "position"], name: "idx_on_draft_answer_id_position_30d7b02a7c", unique: true
    t.index ["draft_answer_id"], name: "index_annes_intake_draft_answer_values_on_draft_answer_id"
  end

  create_table "annes_intake_draft_answers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "field_id", null: false
    t.bigint "form_version_id", null: false
    t.text "raw_value"
    t.bigint "step_run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["step_run_id", "field_id"], name: "index_annes_intake_draft_answers_on_step_run_id_and_field_id", unique: true
  end

  create_table "annes_intake_draft_attachments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "field_id", null: false
    t.bigint "form_version_id", null: false
    t.integer "position", null: false
    t.bigint "step_run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["step_run_id", "field_id", "position"], name: "intake_draft_attachment_order", unique: true
  end

  create_table "annes_intake_field_file_types", force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "extension", null: false
    t.bigint "field_id", null: false
    t.datetime "updated_at", null: false
    t.index ["field_id", "extension"], name: "intake_file_extension", unique: true
    t.index ["field_id"], name: "index_annes_intake_field_file_types_on_field_id"
    t.check_constraint "extension::text ~ '^\\.[a-z0-9]+$'::text", name: "intake_extension_format"
  end

  create_table "annes_intake_field_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "field_id", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["field_id", "value"], name: "intake_option_value", unique: true
    t.index ["field_id"], name: "index_annes_intake_field_options_on_field_id"
    t.index ["id", "field_id"], name: "intake_option_identity", unique: true
    t.check_constraint "\"position\" >= 0", name: "intake_option_position"
  end

  create_table "annes_intake_fields", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "form_version_id", null: false
    t.string "format_key"
    t.text "help_text"
    t.string "key", null: false
    t.string "label", null: false
    t.date "max_date"
    t.datetime "max_datetime"
    t.bigint "max_file_bytes"
    t.integer "max_files"
    t.integer "max_length"
    t.decimal "max_numeric", precision: 25, scale: 6
    t.integer "max_selections"
    t.date "min_date"
    t.datetime "min_datetime"
    t.integer "min_length"
    t.decimal "min_numeric", precision: 25, scale: 6
    t.integer "min_selections"
    t.boolean "must_be_true", default: false, null: false
    t.string "normalizer_key"
    t.string "placeholder"
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "value_type", default: "text", null: false
    t.string "widget", default: "text", null: false
    t.index ["form_version_id", "key"], name: "intake_field_key", unique: true
    t.index ["form_version_id"], name: "index_annes_intake_fields_on_form_version_id"
    t.index ["id", "form_version_id", "value_type"], name: "intake_field_version_type", unique: true
    t.index ["id", "form_version_id"], name: "intake_field_version", unique: true
    t.check_constraint "\"position\" >= 0", name: "intake_position_nonnegative"
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]{0,63}$'::text", name: "intake_field_key_format"
    t.check_constraint "max_file_bytes > 0", name: "intake_max_file_bytes_positive"
    t.check_constraint "max_files > 0", name: "intake_max_files_positive"
    t.check_constraint "max_length >= 0", name: "intake_max_length_nonnegative"
    t.check_constraint "max_selections >= 0", name: "intake_max_selections_nonnegative"
    t.check_constraint "min_date <= max_date", name: "intake_date_bounds"
    t.check_constraint "min_datetime <= max_datetime", name: "intake_datetime_bounds"
    t.check_constraint "min_length <= max_length", name: "intake_length_bounds"
    t.check_constraint "min_length >= 0", name: "intake_min_length_nonnegative"
    t.check_constraint "min_numeric <= max_numeric", name: "intake_numeric_bounds"
    t.check_constraint "min_selections <= max_selections", name: "intake_selections_bounds"
    t.check_constraint "min_selections >= 0", name: "intake_min_selections_nonnegative"
    t.check_constraint "value_type::text = ANY (ARRAY['text'::character varying::text, 'integer'::character varying::text, 'decimal'::character varying::text, 'boolean'::character varying::text, 'date'::character varying::text, 'datetime'::character varying::text, 'single_choice'::character varying::text, 'multiple_choice'::character varying::text, 'attachment'::character varying::text])", name: "intake_field_type"
  end

  create_table "annes_intake_flow_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "flow_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "number", null: false
    t.datetime "published_at"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["flow_id", "number"], name: "index_annes_intake_flow_versions_on_flow_id_and_number", unique: true
    t.index ["flow_id"], name: "index_annes_intake_flow_versions_on_flow_id"
    t.index ["flow_id"], name: "intake_flow_one_draft", unique: true, where: "((status)::text = 'draft'::text)"
    t.index ["flow_id"], name: "intake_flow_one_published", unique: true, where: "((status)::text = 'published'::text)"
    t.check_constraint "number > 0 AND (status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'retired'::character varying::text]))", name: "intake_flow_version_state"
  end

  create_table "annes_intake_flows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_annes_intake_flows_on_key", unique: true
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]{0,63}$'::text", name: "intake_flow_key"
  end

  create_table "annes_intake_form_versions", force: :cascade do |t|
    t.text "completion_message"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "form_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "number", null: false
    t.datetime "published_at"
    t.string "status", default: "draft", null: false
    t.string "submit_label", default: "送信", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["form_id", "number"], name: "intake_version_number", unique: true
    t.index ["form_id"], name: "index_annes_intake_form_versions_on_form_id"
    t.index ["form_id"], name: "intake_one_draft", unique: true, where: "((status)::text = 'draft'::text)"
    t.index ["form_id"], name: "intake_one_published", unique: true, where: "((status)::text = 'published'::text)"
    t.check_constraint "(status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'retired'::character varying::text])) AND number > 0", name: "intake_version_state"
  end

  create_table "annes_intake_forms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_annes_intake_forms_on_key", unique: true
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]{0,63}$'::text", name: "intake_form_key"
  end

  create_table "annes_intake_notification_requests", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "event_key", null: false
    t.text "last_error"
    t.datetime "processing_started_at"
    t.bigint "run_id", null: false
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id", "event_key"], name: "intake_flow_notification_event", unique: true
    t.index ["run_id"], name: "index_annes_intake_notification_requests_on_run_id"
    t.check_constraint "(status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'sent'::character varying::text, 'failed'::character varying::text, 'unknown'::character varying::text])) AND attempts >= 0", name: "intake_flow_notification_state"
  end

  create_table "annes_intake_responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "run_id"], name: "index_annes_intake_responses_on_id_and_run_id", unique: true
    t.index ["run_id"], name: "index_annes_intake_responses_on_run_id", unique: true
  end

  create_table "annes_intake_runs", force: :cascade do |t|
    t.string "context_digest", limit: 64, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "final_key"
    t.bigint "flow_version_id", null: false
    t.string "owner_digest", limit: 64, null: false
    t.string "payload_digest", limit: 64
    t.uuid "receipt_id", null: false
    t.integer "revision", default: 0, null: false
    t.uuid "start_key", null: false
    t.string "status", default: "in_progress", null: false
    t.datetime "submitted_at"
    t.integer "submitted_revision"
    t.integer "token_epoch", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["flow_version_id", "owner_digest", "context_digest", "start_key"], name: "intake_flow_start_key", unique: true
    t.index ["flow_version_id"], name: "index_annes_intake_runs_on_flow_version_id"
    t.index ["id", "flow_version_id"], name: "intake_run_version", unique: true
    t.index ["receipt_id"], name: "index_annes_intake_runs_on_receipt_id", unique: true
    t.check_constraint "(status::text = ANY (ARRAY['in_progress'::character varying::text, 'submitted'::character varying::text, 'cancelled'::character varying::text, 'expired'::character varying::text])) AND revision >= 0 AND token_epoch >= 0", name: "intake_run_state"
    t.check_constraint "status::text = 'submitted'::text AND submitted_at IS NOT NULL AND final_key IS NOT NULL AND payload_digest IS NOT NULL AND submitted_revision IS NOT NULL OR status::text <> 'submitted'::text AND submitted_at IS NULL AND final_key IS NULL AND payload_digest IS NULL AND submitted_revision IS NULL", name: "intake_run_receipt"
  end

  create_table "annes_intake_step_responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "form_version_id", null: false
    t.string "payload_digest", limit: 64, null: false
    t.uuid "receipt_id", null: false
    t.datetime "received_at", null: false
    t.uuid "request_key", null: false
    t.bigint "response_id", null: false
    t.bigint "run_id", null: false
    t.string "step_key", null: false
    t.bigint "step_run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["form_version_id", "received_at", "id"], name: "intake_received"
    t.index ["form_version_id", "request_key"], name: "intake_request_key", unique: true
    t.index ["form_version_id"], name: "index_annes_intake_step_responses_on_form_version_id"
    t.index ["id", "form_version_id"], name: "intake_step_response_version", unique: true
    t.index ["id", "step_run_id"], name: "index_annes_intake_step_responses_on_id_and_step_run_id", unique: true
    t.index ["receipt_id"], name: "index_annes_intake_step_responses_on_receipt_id", unique: true
    t.index ["response_id", "step_key"], name: "index_annes_intake_step_responses_on_response_id_and_step_key", unique: true
    t.index ["response_id"], name: "index_annes_intake_step_responses_on_response_id"
  end

  create_table "annes_intake_step_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "flow_version_id", null: false
    t.bigint "form_version_id", null: false
    t.bigint "run_id", null: false
    t.string "status", default: "draft", null: false
    t.bigint "step_id", null: false
    t.bigint "step_response_id"
    t.datetime "updated_at", null: false
    t.index ["id", "form_version_id"], name: "intake_step_run_version", unique: true
    t.index ["id", "run_id", "form_version_id"], name: "intake_step_run_owner_version", unique: true
    t.index ["run_id", "step_id"], name: "index_annes_intake_step_runs_on_run_id_and_step_id", unique: true
    t.index ["step_response_id"], name: "index_annes_intake_step_runs_on_step_response_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'complete'::character varying::text, 'inactive'::character varying::text])", name: "intake_step_run_state"
  end

  create_table "annes_intake_steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "flow_version_id", null: false
    t.bigint "form_version_id", null: false
    t.string "key", null: false
    t.integer "position", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["flow_version_id", "key"], name: "index_annes_intake_steps_on_flow_version_id_and_key", unique: true
    t.index ["flow_version_id", "position"], name: "index_annes_intake_steps_on_flow_version_id_and_position", unique: true
    t.index ["flow_version_id"], name: "index_annes_intake_steps_on_flow_version_id"
    t.index ["form_version_id"], name: "index_annes_intake_steps_on_form_version_id"
    t.index ["id", "flow_version_id", "form_version_id"], name: "intake_step_identity", unique: true
    t.check_constraint "\"position\" >= 0 AND key::text ~ '^[a-z][a-z0-9_]{0,63}$'::text", name: "intake_step_key"
  end

  create_table "annes_intake_value_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "source_field_id", null: false
    t.bigint "source_step_id", null: false
    t.bigint "step_id", null: false
    t.bigint "target_field_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_field_id"], name: "index_annes_intake_value_mappings_on_source_field_id"
    t.index ["source_step_id"], name: "index_annes_intake_value_mappings_on_source_step_id"
    t.index ["step_id", "target_field_id"], name: "idx_intake_flow_mapping_destination", unique: true
    t.index ["step_id"], name: "index_annes_intake_value_mappings_on_step_id"
    t.index ["target_field_id"], name: "index_annes_intake_value_mappings_on_target_field_id"
  end

  create_table "flow_intake_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "customer_key", null: false
    t.bigint "run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id"], name: "index_flow_intake_requests_on_run_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "annes_intake_answer_attachments", "annes_intake_answers", column: ["answer_id", "field_id", "value_type"], primary_key: ["id", "field_id", "value_type"], name: "intake_attachment_answer_fk"
  add_foreign_key "annes_intake_answer_options", "annes_intake_answers", column: ["answer_id", "field_id", "value_type"], primary_key: ["id", "field_id", "value_type"], name: "intake_selection_answer_fk"
  add_foreign_key "annes_intake_answer_options", "annes_intake_field_options", column: ["field_option_id", "field_id"], primary_key: ["id", "field_id"], name: "intake_selection_option_fk"
  add_foreign_key "annes_intake_answers", "annes_intake_fields", column: ["field_id", "form_version_id", "value_type"], primary_key: ["id", "form_version_id", "value_type"], name: "intake_answer_definition_fk"
  add_foreign_key "annes_intake_answers", "annes_intake_step_responses", column: ["step_response_id", "form_version_id"], primary_key: ["id", "form_version_id"], name: "intake_answer_step_response_fk"
  add_foreign_key "annes_intake_condition_groups", "annes_intake_steps", column: "step_id"
  add_foreign_key "annes_intake_conditions", "annes_intake_condition_groups", column: "condition_group_id"
  add_foreign_key "annes_intake_conditions", "annes_intake_fields", column: "field_id"
  add_foreign_key "annes_intake_conditions", "annes_intake_steps", column: "source_step_id"
  add_foreign_key "annes_intake_draft_answer_values", "annes_intake_draft_answers", column: "draft_answer_id"
  add_foreign_key "annes_intake_draft_answers", "annes_intake_fields", column: ["field_id", "form_version_id"], primary_key: ["id", "form_version_id"], name: "intake_draft_field"
  add_foreign_key "annes_intake_draft_answers", "annes_intake_step_runs", column: ["step_run_id", "form_version_id"], primary_key: ["id", "form_version_id"], name: "intake_draft_step"
  add_foreign_key "annes_intake_draft_attachments", "annes_intake_fields", column: ["field_id", "form_version_id"], primary_key: ["id", "form_version_id"], name: "intake_draft_attachment_field"
  add_foreign_key "annes_intake_draft_attachments", "annes_intake_step_runs", column: ["step_run_id", "form_version_id"], primary_key: ["id", "form_version_id"], name: "intake_draft_attachment_step"
  add_foreign_key "annes_intake_field_file_types", "annes_intake_fields", column: "field_id"
  add_foreign_key "annes_intake_field_options", "annes_intake_fields", column: "field_id"
  add_foreign_key "annes_intake_fields", "annes_intake_form_versions", column: "form_version_id"
  add_foreign_key "annes_intake_flow_versions", "annes_intake_flows", column: "flow_id"
  add_foreign_key "annes_intake_form_versions", "annes_intake_forms", column: "form_id"
  add_foreign_key "annes_intake_notification_requests", "annes_intake_runs", column: "run_id"
  add_foreign_key "annes_intake_responses", "annes_intake_runs", column: "run_id"
  add_foreign_key "annes_intake_runs", "annes_intake_flow_versions", column: "flow_version_id"
  add_foreign_key "annes_intake_step_responses", "annes_intake_form_versions", column: "form_version_id"
  add_foreign_key "annes_intake_step_responses", "annes_intake_responses", column: "response_id"
  add_foreign_key "annes_intake_step_responses", "annes_intake_responses", column: ["response_id", "run_id"], primary_key: ["id", "run_id"], name: "intake_response_run_owner"
  add_foreign_key "annes_intake_step_responses", "annes_intake_step_runs", column: ["step_run_id", "run_id", "form_version_id"], primary_key: ["id", "run_id", "form_version_id"], name: "intake_response_step_owner"
  add_foreign_key "annes_intake_step_runs", "annes_intake_runs", column: ["run_id", "flow_version_id"], primary_key: ["id", "flow_version_id"], name: "intake_step_run_owner"
  add_foreign_key "annes_intake_step_runs", "annes_intake_step_responses", column: ["step_response_id", "form_version_id"], primary_key: ["id", "form_version_id"], name: "intake_step_step_response"
  add_foreign_key "annes_intake_step_runs", "annes_intake_step_responses", column: ["step_response_id", "id"], primary_key: ["id", "step_run_id"], name: "intake_step_response_identity"
  add_foreign_key "annes_intake_step_runs", "annes_intake_steps", column: ["step_id", "flow_version_id", "form_version_id"], primary_key: ["id", "flow_version_id", "form_version_id"], name: "intake_step_run_definition"
  add_foreign_key "annes_intake_steps", "annes_intake_flow_versions", column: "flow_version_id"
  add_foreign_key "annes_intake_steps", "annes_intake_form_versions", column: "form_version_id"
  add_foreign_key "annes_intake_value_mappings", "annes_intake_fields", column: "source_field_id"
  add_foreign_key "annes_intake_value_mappings", "annes_intake_fields", column: "target_field_id"
  add_foreign_key "annes_intake_value_mappings", "annes_intake_steps", column: "source_step_id"
  add_foreign_key "annes_intake_value_mappings", "annes_intake_steps", column: "step_id"
end
