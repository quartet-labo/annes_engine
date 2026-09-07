module PreviewDefinition
  def create_preview_definition
    form = AnnesInquiry::Form.create!(key: "preview", name: "Preview")
    version = form.versions.create!(number: 1, title: "お問い合わせプレビュー", description: "入力内容をご確認ください")
    AnnesInquiry::TypeRegistry::WIDGETS.each do |type, widgets|
      widgets.each do |widget|
        field = version.fields.create!(key: "#{type}_#{widget}", label: "#{type} #{widget}", value_type: type, widget: widget, help_text: "<script>unsafe</script>")
        field.update!(placeholder: "例：入力してください") if AnnesInquiry::TypeRegistry::PLACEHOLDER_WIDGETS.include?(widget)
        field.options.create!(value: "one", label: "選択肢１") if field.choice?
        if type == "attachment"
          field.update!(max_files: 1, max_file_bytes: 1024)
          field.file_types.create!(extension: ".txt")
        end
      end
    end
    version
  end
end
