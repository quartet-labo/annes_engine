module Reservations
  class Filter
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 100

    attr_reader :date, :page, :per_page

    def initialize(params = nil, relation: Reservation.all, **keyword_params)
      raw_params = params || keyword_params
      @params = normalize_params(raw_params)
      @base_relation = relation
      @date = normalize_date(@params[:date])
      @page = normalize_positive_integer(@params[:page], default: 1)
      @per_page = [ normalize_positive_integer(@params[:per_page], default: DEFAULT_PER_PAGE), MAX_PER_PAGE ].min
    end

    def records
      @records ||= filtered_relation.limit(per_page).offset((page - 1) * per_page)
    end

    def total_count
      @total_count ||= filtered_relation.count
    end

    private
      attr_reader :params, :base_relation

      def filtered_relation
        @filtered_relation ||= begin
          relation = base_relation
            .preload(:customer, :reservation_resource)
            .where("reservations.starts_at < ? AND reservations.ends_at > ?", day_end, day_start)
          relation = filter_resource(relation)
          relation = filter_status(relation)
          relation = filter_keyword(relation)
          relation.order(:starts_at, :reservation_number)
        end
      end

      def filter_resource(relation)
        resource_id = normalize_positive_integer(params[:reservation_resource_id], default: nil)
        return relation unless resource_id

        relation.where(reservation_resource_id: resource_id)
      end

      def filter_status(relation)
        status = params[:status].to_s
        return relation if status == "all"
        return relation.where(status:) if status.in?(Reservation::STATUSES)

        relation.where.not(status: "canceled")
      end

      def filter_keyword(relation)
        keyword = params[:q].to_s.strip
        return relation if keyword.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(keyword)}%"
        relation.left_joins(:customer).where(<<~SQL.squish, pattern:)
          reservations.reservation_number ILIKE :pattern OR
          customers.name ILIKE :pattern OR
          customers.name_kana ILIKE :pattern OR
          customers.email ILIKE :pattern OR
          customers.phone ILIKE :pattern
        SQL
      end

      def day_start
        @day_start ||= date.in_time_zone.beginning_of_day
      end

      def day_end
        @day_end ||= day_start.next_day
      end

      def normalize_params(value)
        hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
        hash.with_indifferent_access
      end

      def normalize_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        Time.zone.today
      end

      def normalize_positive_integer(value, default:)
        integer = Integer(value, exception: false)
        integer&.positive? ? integer : default
      end
  end
end
