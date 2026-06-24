module AnneAdmin
  class Pagination
    attr_reader :page, :per_page

    def initialize(page_param, per_page_param, configuration: AnneAdmin.configuration)
      @configuration = configuration
      @page = normalize_positive_integer(page_param, default: 1)
      @per_page = [
        normalize_positive_integer(per_page_param, default: configuration.default_per_page),
        configuration.max_per_page
      ].min
    end

    def apply(relation)
      relation.limit(per_page).offset((page - 1) * per_page)
    end

    private
      attr_reader :configuration

      def normalize_positive_integer(value, default:)
        integer = value.to_i
        integer.positive? ? integer : default
      end
  end
end
