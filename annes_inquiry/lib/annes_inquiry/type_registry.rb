module AnnesInquiry
  module TypeRegistry
    WIDGETS = {
      "text" => %w[text textarea email tel],
      "integer" => %w[number], "decimal" => %w[number],
      "boolean" => %w[checkbox boolean_radio],
      "date" => %w[date], "datetime" => %w[datetime],
      "single_choice" => %w[select radio],
      "multiple_choice" => %w[checkbox_group multi_select],
      "attachment" => %w[file]
    }.transform_values(&:freeze).freeze
    PLACEHOLDER_WIDGETS = %w[text textarea email tel number].freeze
    SETTINGS = {
      "text" => %w[min_length max_length normalizer_key format_key],
      "integer" => %w[min_numeric max_numeric], "decimal" => %w[min_numeric max_numeric],
      "date" => %w[min_date max_date], "datetime" => %w[min_datetime max_datetime],
      "multiple_choice" => %w[min_selections max_selections],
      "attachment" => %w[max_files max_file_bytes]
    }.transform_values(&:freeze).freeze
    NORMALIZERS = %w[trim trim_downcase].freeze
    FORMATS = %w[email].freeze
  end
end
