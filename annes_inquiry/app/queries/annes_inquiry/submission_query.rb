module AnnesInquiry
  class SubmissionQuery
    def initialize(form_id: nil, version_id: nil, from: nil, to: nil, filters: [], page: 1, per_page: 50)
      @form_id, @version_id, @from, @to, @filters = form_id.presence, version_id.presence, from.presence, to.presence, filters
      [@form_id, @version_id].compact.each do |id|
        raise ArgumentError, "フォーム/版IDが不正です" unless id.is_a?(Integer) || (id.is_a?(String) && id.match?(/\A[1-9]\d*\z/))
      end
      @page = Integer(page.presence || 1, exception: false)
      @per_page = Integer(per_page, exception: false)
      raise ArgumentError, "ページ指定が不正です" unless @page&.positive? && @per_page && (1..100).cover?(@per_page)
    end

    def call
      relation = Submission.all
      versions = FormVersion.all
      versions = versions.where(form_id: @form_id) if @form_id
      versions = versions.where(id: @version_id) if @version_id
      relation = relation.where(form_version_id: versions.select(:id)) if @form_id || @version_id
      relation = relation.where("received_at >= ?", day_start(@from)) if @from
      relation = relation.where("received_at < ?", day_start(@to) + 1.day) if @to
      raise ArgumentError, "検索条件は5件以下にしてください" unless @filters.is_a?(Array) && @filters.size <= 5
      @filters.each do |filter|
        raise ArgumentError, "検索条件の形式が不正です" unless filter.is_a?(Hash)
        next if filter.values.all?(&:blank?)
        next if filter["key"].blank? && filter["value"].blank?
        raise ArgumentError, "回答検索にはフォームを指定してください" unless @form_id
        raise ArgumentError, "項目キーが不正です" unless filter["key"].is_a?(String) && filter["key"].match?(/\A[a-z][a-z0-9_]{0,63}\z/)
        fields = Field.where(form_version_id: versions.where(status: %w[published retired]).select(:id), key: filter["key"]).to_a
        raise ArgumentError, "項目キーが不正です" if fields.empty? || fields.any? { |field| field.value_type == "attachment" }
        predicates = fields.map { |field| answer_predicate(field, filter) }
        relation = relation.where(predicates.reduce { |left, right| left.or(right) })
      end
      relation.includes(form_version: :form).order(received_at: :desc, id: :desc).offset((@page - 1) * @per_page).limit(@per_page)
    end

    private
      def answer_predicate(field, filter)
        raw = filter.fetch("value")
        raise ArgumentError, "検索値の形式が不正です" unless raw.is_a?(String)
        value = field.choice? ? raw.presence : ValueConverter.call(field, raw, time_zone: "UTC")
        raise ArgumentError, "検索値を指定してください" if value.nil?
        operator = filter["operator"].presence || "eq"
        answers = Answer.where(field_id: field.id)
          .where("annes_inquiry_answers.submission_id = annes_inquiry_submissions.id")
        if field.choice?
          raise ArgumentError, "選択式は一致で検索してください" unless operator == "eq" && value.is_a?(String)
          answers = answers.joins(options: :field_option).where(annes_inquiry_field_options: { value: value })
        else
          column = Answer.arel_table["#{field.value_type}_value"]
          predicate = case operator
          when "eq" then column.eq(value)
          when "gte", "lte"
            raise ArgumentError, "この型では範囲検索できません" unless %w[integer decimal date datetime].include?(field.value_type)
            operator == "gte" ? column.gteq(value) : column.lteq(value)
          when "contains"
            raise ArgumentError, "部分一致は文字列だけに指定できます" unless field.value_type == "text"
            column.matches("%#{Answer.sanitize_sql_like(value)}%")
          else raise ArgumentError, "検索演算子が不正です"
          end
          answers = answers.where(predicate)
        end
        answers.arel.exists
      end

      def day_start(value)
        raise ArgumentError, "日付はYYYY-MM-DDで指定してください" unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        date = Date.iso8601(value)
        Time.utc(date.year, date.month, date.day)
      end
  end
end
