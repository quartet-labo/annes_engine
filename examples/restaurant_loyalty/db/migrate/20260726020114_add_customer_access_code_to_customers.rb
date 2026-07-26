class AddCustomerAccessCodeToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :access_code_digest, :string
  end
end
