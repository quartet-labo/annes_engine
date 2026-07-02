class CreateCustomerOrganizations < ActiveRecord::Migration[8.1]
  class MigrationCustomer < ActiveRecord::Base
    self.table_name = "customers"
  end

  class MigrationCustomerOrganization < ActiveRecord::Base
    self.table_name = "customer_organizations"
  end

  def up
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

    MigrationCustomer.reset_column_information
    MigrationCustomerOrganization.reset_column_information

    MigrationCustomer.find_each do |customer|
      organization_name = customer.company_name.presence || "#{customer.contact_name} 所属"
      organization = MigrationCustomerOrganization.find_or_create_by!(name: organization_name)
      customer.update!(customer_organization_id: organization.id)
    end

    change_column_null :customers, :customer_organization_id, false
    remove_column :customers, :company_name
  end

  def down
    add_column :customers, :company_name, :string

    MigrationCustomer.reset_column_information

    MigrationCustomer.find_each do |customer|
      organization = MigrationCustomerOrganization.find_by(id: customer.customer_organization_id)
      customer.update_column(:company_name, organization&.name)
    end

    remove_reference :customers, :customer_organization, foreign_key: true
    drop_table :customer_organizations
  end
end
