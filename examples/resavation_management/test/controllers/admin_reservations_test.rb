require "test_helper"

class AdminReservationsTest < ActionDispatch::IntegrationTest
  setup do
    @date = Date.current
    @customer = Customer.create!(name: "山田 太郎", name_kana: "ヤマダ タロウ", email: "taro@example.com")
    @other_customer = Customer.create!(name: "佐藤 花子", name_kana: "サトウ ハナコ")
    @inactive_customer = Customer.create!(name: "無効 顧客", active: false)
    @resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 8)
    @other_resource = ReservationResource.create!(name: "会議室B", kind: "room", capacity: 4)
    @inactive_resource = ReservationResource.create!(name: "利用停止設備", kind: "equipment", capacity: 2, active: false)

    @provisional = create_reservation(
      customer: @customer,
      resource: @resource,
      starts_at: zoned_time(@date, 9),
      ends_at: zoned_time(@date, 10),
      status: "provisional"
    )
    @confirmed = create_reservation(
      customer: @other_customer,
      resource: @other_resource,
      starts_at: zoned_time(@date, 11),
      ends_at: zoned_time(@date, 12),
      status: "confirmed"
    )
  end

  test "anonymous users are redirected to the admin login" do
    get "/admin/reservations/schedule"

    assert_redirected_to "/admin/login"
  end

  test "viewer filters the daily schedule and reads reservation details" do
    canceled = create_reservation(
      customer: @customer,
      resource: @resource,
      starts_at: zoned_time(@date, 13),
      ends_at: zoned_time(@date, 14),
      status: "confirmed"
    )
    actor = account_with_role(:operator)
    Reservations::Transition.new(
      canceled,
      event: :cancel,
      actor:,
      lock_version: canceled.lock_version,
      cancellation_reason: "予定変更"
    ).call
    sign_in_as_role(:viewer)

    get "/admin/reservations/schedule", params: {
      date: @date.iso8601,
      reservation_resource_id: @resource.id,
      status: "provisional",
      q: @customer.name
    }

    assert_response :success
    assert_includes response.body, @provisional.reservation_number
    assert_not_includes response.body, @confirmed.reservation_number
    assert_not_includes response.body, canceled.reservation_number
    assert_includes response.body, "#{@date.strftime('%Y年%m月%d日')}の予約"

    get "/admin/reservations/#{@provisional.id}"
    assert_response :success
    assert_includes response.body, @provisional.reservation_number
    assert_includes response.body, @customer.name
  end

  test "new form only lists active customers and resources" do
    sign_in_as_role(:operator)

    get "/admin/reservations/new"

    assert_response :success
    assert_includes response.body, @customer.display_name
    assert_includes response.body, @resource.name
    assert_not_includes response.body, @inactive_customer.display_name
    assert_not_includes response.body, @inactive_resource.name
    assert_select "input[name='reservation[starts_at]'][type='datetime-local']"
    assert_select "input[name='reservation[ends_at]'][type='datetime-local']"
    assert_select "select[name='reservation[status]']", count: 0
  end

  test "operator creates and updates a reservation without assigning protected fields" do
    operator = sign_in_as_role(:operator)

    assert_difference("Reservation.count") do
      post "/admin/reservations", params: {
        reservation: {
          customer_id: @customer.id,
          reservation_resource_id: @resource.id,
          starts_at: datetime_local(@date, 15),
          ends_at: datetime_local(@date, 16),
          party_size: 3,
          channel: "phone",
          memo: "電話受付",
          reservation_number: "R-INJECTED",
          status: "completed",
          canceled_by_id: operator.id
        }
      }
    end

    created = Reservation.order(:id).last
    assert_redirected_to "/admin/reservations/#{created.id}"
    assert_equal "confirmed", created.status
    assert_not_equal "R-INJECTED", created.reservation_number
    assert_nil created.canceled_by_id

    patch "/admin/reservations/#{created.id}", params: {
      reservation: {
        memo: "更新済み",
        party_size: 4,
        lock_version: created.lock_version,
        reservation_number: "R-REWRITTEN",
        status: "canceled",
        canceled_by_id: operator.id
      }
    }

    assert_redirected_to "/admin/reservations/#{created.id}"
    assert_equal [ "更新済み", 4, "confirmed" ], created.reload.values_at(:memo, :party_size, :status)
    assert_not_equal "R-REWRITTEN", created.reservation_number
    assert_nil created.canceled_by_id
  end

  test "edit form retains currently selected inactive associations and lock version" do
    legacy_customer = Customer.create!(name: "既存無効顧客")
    legacy_resource = ReservationResource.create!(name: "既存無効設備", kind: "equipment", capacity: 3)
    reservation = create_reservation(
      customer: legacy_customer,
      resource: legacy_resource,
      starts_at: zoned_time(@date, 16),
      ends_at: zoned_time(@date, 17)
    )
    legacy_customer.update!(active: false)
    legacy_resource.update!(active: false)
    sign_in_as_role(:operator)

    get "/admin/reservations/#{reservation.id}/edit"

    assert_response :success
    assert_includes response.body, legacy_customer.display_name
    assert_includes response.body, legacy_resource.name
    assert_not_includes response.body, @inactive_customer.display_name
    assert_not_includes response.body, @inactive_resource.name
    assert_select "input[name='reservation[lock_version]'][type='hidden'][value='#{reservation.lock_version}']"
  end

  test "validation and normal overlap errors render the form with 422" do
    sign_in_as_role(:operator)

    post "/admin/reservations", params: {
      reservation: {
        customer_id: @customer.id,
        reservation_resource_id: @resource.id,
        starts_at: datetime_local(@date, 10),
        ends_at: datetime_local(@date, 9),
        party_size: 0,
        channel: "phone"
      }
    }
    assert_response :unprocessable_entity
    assert_includes response.body, "入力内容を確認してください"

    post "/admin/reservations", params: {
      reservation: {
        customer_id: @customer.id,
        reservation_resource_id: @resource.id,
        starts_at: datetime_local(@date, 9, 30),
        ends_at: datetime_local(@date, 10, 30),
        party_size: 1,
        channel: "email"
      }
    }
    assert_response :unprocessable_entity
    assert_includes response.body, "指定時間は既に予約されています"
  end

  test "database overlap conflict renders a safe 409 message" do
    sign_in_as_role(:operator)
    failed_reservation = Reservation.new(
      customer: @customer,
      reservation_resource: @resource,
      starts_at: zoned_time(@date, 15),
      ends_at: zoned_time(@date, 16),
      party_size: 1,
      channel: "other"
    )
    conflicting_service = Struct.new(:reservation) do
      def call
        raise Reservations::ConflictError, Reservations::ConflictError::OVERLAP_MESSAGE
      end
    end.new(failed_reservation)

    original_constructor = Reservations::Create.method(:new)
    Reservations::Create.define_singleton_method(:new) { |*, **| conflicting_service }

    begin
      post "/admin/reservations", params: {
        reservation: {
          customer_id: @customer.id,
          reservation_resource_id: @resource.id,
          starts_at: datetime_local(@date, 15),
          ends_at: datetime_local(@date, 16),
          party_size: 1,
          channel: "other"
        }
      }
    ensure
      Reservations::Create.define_singleton_method(:new, original_constructor)
    end

    assert_response :conflict
    assert_includes response.body, "別の予約が先に登録されました"
    assert_not_includes response.body, "PG::ExclusionViolation"
  end

  test "stale update returns 409 without overwriting newer data" do
    sign_in_as_role(:operator)
    @confirmed.update!(memo: "先行更新")

    patch "/admin/reservations/#{@confirmed.id}", params: {
      reservation: { memo: "古い画面の更新", lock_version: @confirmed.lock_version - 1 }
    }

    assert_response :conflict
    assert_includes response.body, "別のスタッフが先に更新しました。最新情報を確認してください"
    assert_equal "先行更新", @confirmed.reload.memo
  end

  test "operator confirms and cancels reservations through dedicated transitions" do
    operator = sign_in_as_role(:operator)

    patch "/admin/reservations/#{@provisional.id}/confirm", params: {
      reservation: { lock_version: @provisional.lock_version, status: "completed" }
    }
    assert_redirected_to "/admin/reservations/#{@provisional.id}"
    assert_equal "confirmed", @provisional.reload.status

    patch "/admin/reservations/#{@confirmed.id}/cancel", params: {
      reservation: {
        lock_version: @confirmed.lock_version,
        cancellation_reason: "お客様都合",
        canceled_by_id: account_with_role(:admin).id
      }
    }
    assert_redirected_to "/admin/reservations/#{@confirmed.id}"
    assert_equal "canceled", @confirmed.reload.status
    assert_equal operator, @confirmed.canceled_by
    assert_equal "お客様都合", @confirmed.cancellation_reason
    assert_not_nil @confirmed.canceled_at
  end

  test "operator completes and marks past confirmed reservations as no-show" do
    past_date = @date - 1.day
    completed = create_reservation(
      customer: @customer,
      resource: @resource,
      starts_at: zoned_time(past_date, 6),
      ends_at: zoned_time(past_date, 7)
    )
    no_show = create_reservation(
      customer: @other_customer,
      resource: @other_resource,
      starts_at: zoned_time(past_date, 7),
      ends_at: zoned_time(past_date, 8)
    )
    sign_in_as_role(:operator)

    patch "/admin/reservations/#{completed.id}/complete", params: {
      reservation: { lock_version: completed.lock_version }
    }
    assert_redirected_to "/admin/reservations/#{completed.id}"

    patch "/admin/reservations/#{no_show.id}/mark_no_show", params: {
      reservation: { lock_version: no_show.lock_version }
    }
    assert_redirected_to "/admin/reservations/#{no_show.id}"

    assert_equal "completed", completed.reload.status
    assert_equal "no_show", no_show.reload.status
  end

  test "invalid transition renders 422 and preserves the current state" do
    future_date = @date + 1.day
    future_reservation = create_reservation(
      customer: @customer,
      resource: @resource,
      starts_at: zoned_time(future_date, 11),
      ends_at: zoned_time(future_date, 12)
    )
    sign_in_as_role(:operator)

    patch "/admin/reservations/#{future_reservation.id}/complete", params: {
      reservation: { lock_version: future_reservation.lock_version }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "開始時刻前の予約は完了または無断キャンセルにできません"
    assert_equal "confirmed", future_reservation.reload.status
  end

  test "viewer sees no write actions and write requests return 403" do
    sign_in_as_role(:viewer)

    get "/admin/reservations/#{@provisional.id}"
    assert_response :success
    assert_not_includes response.body, "予約を編集"
    assert_not_includes response.body, "予約を確定"
    assert_not_includes response.body, "予約を取消"
    assert_not_includes response.body, "利用完了"
    assert_not_includes response.body, "無断キャンセル"

    assert_no_difference("Reservation.count") do
      post "/admin/reservations", params: {
        reservation: {
          customer_id: @customer.id,
          reservation_resource_id: @resource.id,
          starts_at: datetime_local(@date, 15),
          ends_at: datetime_local(@date, 16),
          party_size: 1,
          channel: "other"
        }
      }
    end
    assert_response :forbidden

    assert_no_changes -> { @provisional.reload.memo } do
      patch "/admin/reservations/#{@provisional.id}", params: {
        reservation: { memo: "不可", lock_version: @provisional.lock_version }
      }
    end
    assert_response :forbidden

    patch "/admin/reservations/#{@provisional.id}/cancel", params: {
      reservation: { lock_version: @provisional.lock_version }
    }
    assert_response :forbidden
    assert_equal "provisional", @provisional.reload.status
  end

  test "missing reservation returns 404" do
    sign_in_as_role(:viewer)

    get "/admin/reservations/999999999"

    assert_response :not_found
  end

  private
    def create_reservation(customer:, resource:, starts_at:, ends_at:, status: "confirmed")
      Reservation.create!(
        customer:,
        reservation_resource: resource,
        starts_at:,
        ends_at:,
        status:,
        party_size: 1,
        channel: "other"
      )
    end

    def zoned_time(date, hour, minute = 0)
      Time.zone.local(date.year, date.month, date.day, hour, minute)
    end

    def datetime_local(date, hour, minute = 0)
      zoned_time(date, hour, minute).strftime("%Y-%m-%dT%H:%M")
    end
end
