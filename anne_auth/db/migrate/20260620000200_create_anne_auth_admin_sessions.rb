class CreateAnneAuthAdminSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
