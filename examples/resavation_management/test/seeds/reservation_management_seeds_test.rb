require "test_helper"

class ReservationManagementSeedsTest < ActiveSupport::TestCase
  SEED_ACCOUNT_EMAILS = %w[
    admin@example.com
    operator@example.com
    viewer@example.com
  ].freeze
  SEED_RESERVATION_NUMBERS = %w[
    R-DEMO-001
    R-DEMO-002
    R-DEMO-003
    R-DEMO-004
    R-DEMO-005
    R-DEMO-006
  ].freeze

  test "seed can be loaded twice without increasing record counts" do
    travel_to ReservationManagementSeedTestHelper::SEED_TIME do
      load_reservation_management_seeds
      counts_after_first_load = seed_record_counts

      load_reservation_management_seeds

      assert_equal counts_after_first_load, seed_record_counts
      assert_equal SEED_ACCOUNT_EMAILS.sort, Account.where(email: SEED_ACCOUNT_EMAILS).pluck(:email).sort
      assert_equal SEED_RESERVATION_NUMBERS.sort,
        Reservation.where(reservation_number: SEED_RESERVATION_NUMBERS).pluck(:reservation_number).sort
    end
  end

  test "seed accounts have the documented credentials and permission matrix" do
    with_reservation_management_seeds do
      AccessHelpers::ROLE_PERMISSIONS.each do |role_key, resource_actions|
        account = Account.find_by!(email: "#{role_key}@example.com")
        role = AnnesAccess::Role.find_by!(key: role_key.to_s)
        expected_permissions = resource_actions.flat_map do |resource, actions|
          actions.map { |action| [ resource, action ] }
        end.sort

        assert account.authenticate(ReservationManagementSeedTestHelper::SEED_PASSWORD),
          "#{account.email} should authenticate with the seed password"
        assigned_role_keys = AnnesAccess::Assignment
          .where(principal: account)
          .joins(:role)
          .pluck("annes_access_roles.key")
        assert_equal [ role_key.to_s ], assigned_role_keys
        assert_equal expected_permissions, role.permissions.pluck(:resource, :action).sort
      end
    end
  end

  test "seed includes active and inactive masters and every reservation status" do
    with_reservation_management_seeds do
      assert Customer.find_by!(customer_number: "C-DEMO-001").active?
      assert_not Customer.find_by!(customer_number: "C-DEMO-999").active?
      assert ReservationResource.find_by!(name: "会議室A").active?
      assert ReservationResource.find_by!(name: "貸出機材").active?
      assert_not ReservationResource.find_by!(name: "利用停止対象").active?

      statuses = Reservation.where(reservation_number: SEED_RESERVATION_NUMBERS).distinct.pluck(:status)
      assert_equal Reservation::STATUSES.sort, statuses.sort
    end
  end

  test "seed times use Tokyo business dates and allow consecutive reservations" do
    with_reservation_management_seeds do
      first = Reservation.find_by!(reservation_number: "R-DEMO-001")
      second = Reservation.find_by!(reservation_number: "R-DEMO-002")
      provisional = Reservation.find_by!(reservation_number: "R-DEMO-006")

      assert_equal Date.current, first.starts_at.in_time_zone.to_date
      assert_equal first.reservation_resource, second.reservation_resource
      assert_equal first.ends_at, second.starts_at
      assert_equal Date.current + 1.day, provisional.starts_at.in_time_zone.to_date
      assert_equal "provisional", provisional.status
    end
  end

  test "reseed refreshes demo reservations for a later Tokyo business date" do
    travel_to ReservationManagementSeedTestHelper::SEED_TIME do
      load_reservation_management_seeds
    end

    travel_to ReservationManagementSeedTestHelper::SEED_TIME + 3.days do
      assert_no_difference("Reservation.count") do
        load_reservation_management_seeds
      end

      expected_dates = {
        "R-DEMO-001" => Date.current,
        "R-DEMO-002" => Date.current,
        "R-DEMO-003" => Date.current,
        "R-DEMO-004" => Date.current - 1.day,
        "R-DEMO-005" => Date.current - 1.day,
        "R-DEMO-006" => Date.current + 1.day
      }
      expected_dates.each do |reservation_number, expected_date|
        reservation = Reservation.find_by!(reservation_number:)
        assert_equal expected_date, reservation.starts_at.in_time_zone.to_date
      end
    end
  end

  private
    def seed_record_counts
      [
        Account,
        AnnesAccess::Role,
        AnnesAccess::Permission,
        AnnesAccess::RolePermission,
        AnnesAccess::Assignment,
        Customer,
        ReservationResource,
        Reservation
      ].to_h { |model| [ model.name, model.count ] }
    end
end
