module AnnesInquiry
  module FormHelper
    def inquiry_host_action(action, notification: nil)
      return unless action.is_a?(Hash) && action[:path].is_a?(String) && action[:path].match?(/\A\/(?!\/)[^\x00-\x20\\]*\z/)
      method = action.fetch(:method, :get).to_s
      return unless %w[get post].include?(method)
      return if method == "post" && (!notification || !notification.failed?)
      action.merge(method: method)
    end

    def inquiry_notification_status(status)
      { "pending" => "未送信", "processing" => "送信処理中", "sent" => "送信済み", "failed" => "送信失敗", "unknown" => "結果不明" }.fetch(status)
    end

    def inquiry_setting_label(key)
      { "min_length" => "最小文字数", "max_length" => "最大文字数", "normalizer_key" => "正規化",
        "format_key" => "形式検証", "min_numeric" => "最小値", "max_numeric" => "最大値", "min_date" => "最小日付",
        "max_date" => "最大日付", "min_datetime" => "最小日時（UTC）", "max_datetime" => "最大日時（UTC）",
        "min_selections" => "最小選択数", "max_selections" => "最大選択数", "max_files" => "最大ファイル数",
        "max_file_bytes" => "最大ファイルサイズ（バイト）" }.fetch(key)
    end

    def inquiry_field_attributes(field, input, scope:)
      id = "#{scope}_#{field.key}"
      { id: id, required: field.required, placeholder: field.placeholder,
        aria: { describedby: "#{id}_help #{id}_errors", invalid: input.errors[field.key].any? ? "true" : nil } }
    end

    def inquiry_raw_value(input, field)
      input.raw_values.is_a?(Hash) ? input.raw_values[field.key] : nil
    end
  end
end
