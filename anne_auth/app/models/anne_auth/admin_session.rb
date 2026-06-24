module AnneAuth
  class AdminSession < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :admin_user, class_name: "::AdminUser", inverse_of: :sessions
  end
end
