module Admin
  class ReservationsController < BaseController
    CONFLICT_MESSAGE = "別の予約が先に登録されました。入力内容を確認してください。"
    STALE_MESSAGE = "別のスタッフが先に更新しました。最新情報を確認してください。"
    FORM_ATTRIBUTES = %i[
      customer_id
      reservation_resource_id
      starts_at
      ends_at
      party_size
      channel
      memo
      lock_version
    ].freeze

    before_action :set_reservation, only: %i[
      show
      edit
      update
      confirm
      cancel_confirmation
      cancel
      complete
      mark_no_show
    ]
    before_action :authorize_read!, only: %i[schedule index show]
    before_action :authorize_create!, only: %i[new create]
    before_action :authorize_update!, only: %i[edit update]
    before_action :authorize_confirm!, only: :confirm
    before_action :authorize_cancel!, only: %i[cancel_confirmation cancel]
    before_action :authorize_complete!, only: :complete
    before_action :authorize_no_show!, only: :mark_no_show

    rescue_from Reservations::ConflictError, with: :render_conflict
    rescue_from Reservations::InvalidTransitionError, with: :render_invalid_transition
    rescue_from ActiveRecord::StaleObjectError, with: :render_stale

    def schedule
      load_schedule
    end

    def index
      load_schedule
    end

    def show
    end

    def new
      @reservation = Reservation.new(new_reservation_defaults)
      load_form_options
    end

    def create
      service = Reservations::Create.new(reservation_attributes)
      @reservation = service.reservation
      service.call

      if @reservation.persisted?
        redirect_to admin_reservation_path(@reservation), notice: "予約を登録しました。"
      else
        load_form_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      return render_terminal_record if @reservation.terminal?

      load_form_options
    end

    def update
      Reservations::Update.new(
        @reservation,
        reservation_attributes,
        lock_version: reservation_form_params[:lock_version]
      ).call

      if @reservation.errors.empty?
        redirect_to admin_reservation_path(@reservation), notice: "予約を更新しました。"
      else
        load_form_options
        render :edit, status: :unprocessable_entity
      end
    end

    def confirm
      transition!(:confirm, "予約を確定しました。")
    end

    def cancel_confirmation
    end

    def cancel
      transition!(:cancel, "予約を取り消しました。", cancellation_reason: transition_params[:cancellation_reason])
    end

    def complete
      transition!(:complete, "予約を利用完了にしました。")
    end

    def mark_no_show
      transition!(:mark_no_show, "予約を無断キャンセルにしました。")
    end

    private
      def set_reservation
        @reservation = Reservation.includes(:customer, :reservation_resource, :canceled_by).find(params[:id])
      end

      def authorize_read!
        authorize_access!(:read, :reservations, record: @reservation)
      end

      def authorize_create!
        authorize_access!(:create, :reservations)
      end

      def authorize_update!
        authorize_access!(:update, :reservations, record: @reservation)
      end

      def authorize_confirm!
        authorize_access!(:confirm, :reservations, record: @reservation)
      end

      def authorize_cancel!
        authorize_access!(:cancel, :reservations, record: @reservation)
      end

      def authorize_complete!
        authorize_access!(:complete, :reservations, record: @reservation)
      end

      def authorize_no_show!
        authorize_access!(:no_show, :reservations, record: @reservation)
      end

      def load_schedule
        @filter = Reservations::Filter.new(filter_params)
        @reservations = @filter.records
        @reservation_resources = ReservationResource.order(:name)
      end

      def load_form_options
        @customers = Customer.active.order(:name).to_a
        @reservation_resources = ReservationResource.active.order(:name).to_a
        include_current_option(@customers, @reservation.customer)
        include_current_option(@reservation_resources, @reservation.reservation_resource)
      end

      def include_current_option(collection, record)
        collection << record if record.present? && collection.none? { |item| item.id == record.id }
      end

      def new_reservation_defaults
        date = Date.iso8601(params[:date].to_s)
        starts_at = date.in_time_zone.change(hour: 9)
        { starts_at:, ends_at: starts_at + 1.hour, party_size: 1, channel: "other" }
      rescue Date::Error
        { party_size: 1, channel: "other" }
      end

      def filter_params
        params.permit(:date, :reservation_resource_id, :status, :q, :page, :per_page)
      end

      def reservation_attributes
        reservation_form_params.except(:lock_version)
      end

      def reservation_form_params
        @reservation_form_params ||= params.require(:reservation).permit(*FORM_ATTRIBUTES)
      end

      def transition_params
        @transition_params ||= params
          .fetch(:reservation, ActionController::Parameters.new)
          .permit(:lock_version, :cancellation_reason)
      end

      def transition!(event, notice, cancellation_reason: nil)
        Reservations::Transition.new(
          @reservation,
          event:,
          actor: Account.find(current_account.id),
          lock_version: transition_params[:lock_version],
          cancellation_reason:
        ).call
        redirect_to admin_reservation_path(@reservation), notice:
      end

      def render_terminal_record
        @reservation.errors.add(:base, "完了・取消済みの予約は編集できません。")
        render :show, status: :unprocessable_entity
      end

      def render_conflict
        @reservation ||= Reservation.new(reservation_attributes)
        @reservation.errors.add(:base, CONFLICT_MESSAGE)
        render_reservation_error(:conflict)
      end

      def render_stale
        @reservation.errors.add(:base, STALE_MESSAGE)
        render_reservation_error(:conflict)
      end

      def render_invalid_transition(error)
        @reservation.errors.add(:base, error.message)
        render :show, status: :unprocessable_entity
      end

      def render_reservation_error(status)
        case action_name
        when "create"
          load_form_options
          render :new, status:
        when "update"
          load_form_options
          render :edit, status:
        else
          render :show, status:
        end
      end
  end
end
