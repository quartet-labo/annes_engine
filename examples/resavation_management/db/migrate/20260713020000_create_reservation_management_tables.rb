class CreateReservationManagementTables < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :customers do |t|
      t.string :customer_number, null: false
      t.string :name, null: false
      t.string :name_kana
      t.string :email
      t.string :phone
      t.boolean :active, null: false, default: true
      t.text :memo

      t.timestamps
    end

    add_index :customers, :customer_number, unique: true
    add_index :customers, :name
    add_index :customers, :name_kana
    add_index :customers, :email
    add_index :customers, :phone
    add_index :customers, :active

    create_table :reservation_resources do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.integer :capacity, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.text :memo

      t.timestamps
    end

    add_index :reservation_resources, :name
    add_index :reservation_resources, :kind
    add_index :reservation_resources, :active
    add_check_constraint :reservation_resources,
      "kind IN ('facility', 'room', 'equipment', 'staff', 'other')",
      name: "reservation_resources_kind_known"
    add_check_constraint :reservation_resources,
      "capacity >= 1",
      name: "reservation_resources_capacity_positive"

    create_table :reservations do |t|
      t.string :reservation_number, null: false
      t.references :customer, null: false, foreign_key: true
      t.references :reservation_resource, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "confirmed"
      t.integer :party_size, null: false, default: 1
      t.string :channel, null: false, default: "other"
      t.text :memo
      t.datetime :canceled_at
      t.references :canceled_by, foreign_key: { to_table: :accounts }
      t.text :cancellation_reason
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :reservations, :reservation_number, unique: true
    add_index :reservations, [ :reservation_resource_id, :starts_at ]
    add_index :reservations, [ :status, :starts_at ]
    add_index :reservations, [ :customer_id, :starts_at ]
    add_index :reservations, :ends_at

    add_check_constraint :reservations,
      "ends_at > starts_at",
      name: "reservations_ends_after_start"
    add_check_constraint :reservations,
      <<~SQL.squish,
        (
          ((starts_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Tokyo')::date =
          ((ends_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Tokyo')::date
        )
      SQL
      name: "reservations_same_tokyo_business_day"
    add_check_constraint :reservations,
      "status IN ('provisional', 'confirmed', 'completed', 'canceled', 'no_show')",
      name: "reservations_status_known"
    add_check_constraint :reservations,
      "party_size >= 1",
      name: "reservations_party_size_positive"
    add_check_constraint :reservations,
      "channel IN ('phone', 'email', 'counter', 'web', 'other')",
      name: "reservations_channel_known"
    add_check_constraint :reservations,
      <<~SQL.squish,
        (
          status = 'canceled' AND canceled_at IS NOT NULL AND canceled_by_id IS NOT NULL
        ) OR (
          status <> 'canceled' AND canceled_at IS NULL AND canceled_by_id IS NULL AND cancellation_reason IS NULL
        )
      SQL
      name: "reservations_cancellation_metadata_consistent"

    add_exclusion_constraint :reservations,
      "reservation_resource_id WITH =, tsrange(starts_at, ends_at, '[)') WITH &&",
      using: :gist,
      where: "status IN ('provisional', 'confirmed')",
      name: "reservations_no_blocking_time_overlap"
  end
end
