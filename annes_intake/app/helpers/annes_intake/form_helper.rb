module AnnesIntake
  module FormHelper
    TYPE_LABELS = {"text" => "文字", "integer" => "整数", "decimal" => "小数", "boolean" => "はい・いいえ", "date" => "日付", "datetime" => "日時", "single_choice" => "一つ選択", "multiple_choice" => "複数選択", "attachment" => "ファイル添付"}.freeze
    WIDGET_LABELS = {"text" => "1行", "textarea" => "複数行", "email" => "メール", "tel" => "電話", "number" => "数値", "checkbox" => "同意チェック", "boolean_radio" => "はい・いいえ", "date" => "日付", "datetime" => "日時", "select" => "選択リスト", "radio" => "ラジオボタン", "checkbox_group" => "チェックリスト", "multi_select" => "複数選択リスト", "file" => "ファイル"}.freeze
    def intake_type_options = TYPE_LABELS.map { |value, label| [label, value] }
    def intake_widget_options = WIDGET_LABELS.map { |value, label| [label, value] }

    def intake_host_action(action, notification: nil)
      return unless action.is_a?(Hash) && action[:path].is_a?(String) && action[:path].match?(/\A\/(?!\/)[^\x00-\x20\\]*\z/)
      method = action.fetch(:method, :get).to_s
      return unless %w[get post].include?(method)
      return if method == "post" && (!notification || !notification.failed?)
      action.merge(method: method)
    end

    def intake_notification_status(status)
      { "pending" => "未送信", "processing" => "送信処理中", "sent" => "送信済み", "failed" => "送信失敗", "unknown" => "結果不明" }.fetch(status)
    end

    def intake_setting_label(key)
      { "min_length" => "最小文字数", "max_length" => "最大文字数", "normalizer_key" => "正規化",
        "format_key" => "形式検証", "min_numeric" => "最小値", "max_numeric" => "最大値", "min_date" => "最小日付",
        "max_date" => "最大日付", "min_datetime" => "最小日時（UTC）", "max_datetime" => "最大日時（UTC）",
        "min_selections" => "最小選択数", "max_selections" => "最大選択数", "max_files" => "最大ファイル数",
        "max_file_bytes" => "最大ファイルサイズ（バイト）" }.fetch(key)
    end

    def intake_error_messages(input)
      labels = input.version.fields.to_h { |field| [field.key, field.label] }
      input.errors.map { |error| error.attribute == :base ? error.message : "#{labels.fetch(error.attribute.to_s, error.attribute.to_s)}#{error.message}" }
    end

    def intake_field_attributes(field, input, scope:)
      AnnesFormKit::Renderer.field_attributes(field, input, scope: scope)
    end

    def intake_raw_value(input, field)
      input.raw_values.is_a?(Hash) ? input.raw_values[field.key] : nil
    end
  end
end
