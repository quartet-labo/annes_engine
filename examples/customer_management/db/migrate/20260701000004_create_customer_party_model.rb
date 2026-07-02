class CreateCustomerPartyModel < ActiveRecord::Migration[8.1]
  class MigrationCustomerOrganization < ActiveRecord::Base
    self.table_name = "customer_organizations"
  end

  class MigrationCustomer < ActiveRecord::Base
    self.table_name = "customers"
  end

  class MigrationProject < ActiveRecord::Base
    self.table_name = "projects"
  end

  class MigrationOrganization < ActiveRecord::Base
    self.table_name = "organizations"
  end

  class MigrationPerson < ActiveRecord::Base
    self.table_name = "persons"
  end

  class MigrationCustomerContact < ActiveRecord::Base
    self.table_name = "customer_contacts"
  end

  def up
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :name_kana
      t.string :phone
      t.string :website
      t.text :memo

      t.timestamps
    end
    add_index :organizations, :name

    create_table :persons do |t|
      t.string :name, null: false
      t.string :name_kana
      t.string :email
      t.string :phone
      t.text :memo

      t.timestamps
    end
    add_index :persons, :name
    add_index :persons, :email

    add_column :customers, :customer_number, :string
    add_column :customers, :kind, :string
    add_column :customers, :status, :string, default: "active"
    add_column :customers, :source, :string
    add_reference :customers, :person, foreign_key: { to_table: :persons }
    add_reference :customers, :organization, foreign_key: true

    create_table :customer_contacts do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: { to_table: :persons }
      t.string :role, null: false, default: "primary"
      t.string :department
      t.string :title
      t.string :email
      t.string :phone
      t.boolean :primary, null: false, default: false
      t.text :memo

      t.timestamps
    end
    add_index :customer_contacts, :role
    add_index :customer_contacts, :primary

    reset_migration_models
    migrate_legacy_organizations
    migrate_remaining_customers_as_person_customers

    change_column_null :customers, :customer_number, false
    change_column_null :customers, :kind, false
    change_column_null :customers, :status, false
    add_index :customers, :customer_number, unique: true
    add_index :customers, :kind
    add_index :customers, :status
    add_check_constraint :customers,
      "((kind = 'person' AND person_id IS NOT NULL AND organization_id IS NULL) OR (kind = 'organization' AND organization_id IS NOT NULL AND person_id IS NULL))",
      name: "customers_kind_target_check"

    remove_reference :customers, :customer_organization, foreign_key: true
    remove_column :customers, :contact_name
    remove_column :customers, :email
    remove_column :customers, :phone
    drop_table :customer_organizations
  end

  def down
    create_table :customer_organizations do |t|
      t.string :name, null: false
      t.string :name_kana
      t.string :phone
      t.string :website
      t.text :memo

      t.timestamps
    end
    add_index :customer_organizations, :name

    add_reference :customers, :customer_organization, foreign_key: true
    add_column :customers, :contact_name, :string
    add_column :customers, :email, :string
    add_column :customers, :phone, :string

    reset_migration_models
    restore_legacy_customer_columns

    change_column_null :customers, :customer_organization_id, false
    change_column_null :customers, :contact_name, false
    change_column_null :customers, :email, false
    add_index :customers, :contact_name
    add_index :customers, :email

    remove_check_constraint :customers, name: "customers_kind_target_check"
    remove_index :customers, :customer_number
    remove_index :customers, :kind
    remove_index :customers, :status
    drop_table :customer_contacts
    remove_reference :customers, :person, foreign_key: { to_table: :persons }
    remove_reference :customers, :organization, foreign_key: true
    remove_column :customers, :source
    remove_column :customers, :status
    remove_column :customers, :kind
    remove_column :customers, :customer_number
    drop_table :persons
    drop_table :organizations
  end

  private
    def migrate_legacy_organizations
      return unless table_exists?(:customer_organizations)

      MigrationCustomerOrganization.order(:id).find_each do |legacy_organization|
        organization = MigrationOrganization.create!(
          name: legacy_organization.name,
          name_kana: legacy_organization.name_kana,
          phone: legacy_organization.phone,
          website: legacy_organization.website,
          memo: legacy_organization.memo
        )

        legacy_customers = MigrationCustomer.where(customer_organization_id: legacy_organization.id).order(:id).to_a
        if legacy_customers.present?
          migrate_legacy_organization_customer(organization, legacy_customers)
        else
          MigrationCustomer.create!(
            customer_number: customer_number_for("ORG", organization.id),
            kind: "organization",
            status: "active",
            organization_id: organization.id,
            memo: organization.memo
          )
        end
      end
    end

    def migrate_legacy_organization_customer(organization, legacy_customers)
      primary_customer = legacy_customers.first

      legacy_customers.each_with_index do |legacy_customer, index|
        person = MigrationPerson.create!(
          name: legacy_customer.contact_name.presence || legacy_customer.email.presence || "担当者#{legacy_customer.id}",
          email: legacy_customer.email,
          phone: legacy_customer.phone,
          memo: legacy_customer.memo
        )

        MigrationCustomerContact.create!(
          customer_id: primary_customer.id,
          person_id: person.id,
          role: index.zero? ? "primary" : "other",
          email: legacy_customer.email,
          phone: legacy_customer.phone,
          primary: index.zero?,
          memo: legacy_customer.memo
        )

        next if legacy_customer.id == primary_customer.id

        MigrationProject.where(customer_id: legacy_customer.id).update_all(customer_id: primary_customer.id)
        legacy_customer.delete
      end

      primary_customer.update!(
        customer_number: customer_number_for("C", primary_customer.id),
        kind: "organization",
        status: "active",
        organization_id: organization.id,
        person_id: nil,
        memo: organization.memo.presence || primary_customer.memo
      )
    end

    def migrate_remaining_customers_as_person_customers
      MigrationCustomer.where(kind: nil).order(:id).find_each do |legacy_customer|
        person = MigrationPerson.create!(
          name: legacy_customer.contact_name.presence || legacy_customer.email.presence || "個人顧客#{legacy_customer.id}",
          email: legacy_customer.email,
          phone: legacy_customer.phone,
          memo: legacy_customer.memo
        )

        legacy_customer.update!(
          customer_number: customer_number_for("C", legacy_customer.id),
          kind: "person",
          status: "active",
          person_id: person.id,
          organization_id: nil
        )
      end
    end

    def restore_legacy_customer_columns
      MigrationCustomer.order(:id).find_each do |customer|
        legacy_organization = legacy_organization_for(customer)
        contact = MigrationCustomerContact.where(customer_id: customer.id).order(primary: :desc, id: :asc).first
        person = contact ? MigrationPerson.find_by(id: contact.person_id) : MigrationPerson.find_by(id: customer.person_id)

        customer.update_columns(
          customer_organization_id: legacy_organization.id,
          contact_name: person&.name.presence || legacy_organization.name,
          email: contact&.email.presence || person&.email.presence || "#{customer.customer_number.downcase}@example.invalid",
          phone: contact&.phone.presence || person&.phone,
          updated_at: Time.current
        )
      end
    end

    def legacy_organization_for(customer)
      organization = MigrationOrganization.find_by(id: customer.organization_id)
      person = MigrationPerson.find_by(id: customer.person_id)
      name = organization&.name.presence || "#{person&.name.presence || customer.customer_number} 所属"

      MigrationCustomerOrganization.find_or_create_by!(name:) do |legacy_organization|
        legacy_organization.name_kana = organization&.name_kana
        legacy_organization.phone = organization&.phone
        legacy_organization.website = organization&.website
        legacy_organization.memo = organization&.memo
      end
    end

    def customer_number_for(prefix, id)
      "#{prefix}#{id.to_i.to_s.rjust(4, "0")}"
    end

    def reset_migration_models
      [
        MigrationCustomerOrganization,
        MigrationCustomer,
        MigrationProject,
        MigrationOrganization,
        MigrationPerson,
        MigrationCustomerContact
      ].each(&:reset_column_information)
    end
end
