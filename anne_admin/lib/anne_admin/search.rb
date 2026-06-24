module AnneAdmin
  class Search
    def initialize(resource, relation, keyword)
      @resource = resource
      @relation = relation
      @keyword = keyword.to_s.strip
    end

    def apply
      return relation if keyword.blank? || resource.searchable_attributes.blank?

      columns = searchable_columns
      return relation if columns.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(keyword)}%"
      table = resource.model_class.arel_table
      conditions = columns.map do |column|
        table[column].matches(pattern)
      end.reduce { |left, right| left.or(right) }

      relation.where(conditions)
    end

    private
      attr_reader :resource, :relation, :keyword

      def searchable_columns
        columns = resource.model_class.columns_hash
        resource.searchable_attributes.map(&:to_s).select do |column_name|
          columns[column_name]&.type.in?(%i[string text])
        end
      end
  end
end
