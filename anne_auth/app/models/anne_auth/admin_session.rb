module AnneAuth
  class AdminSession < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :admin_user,
      class_name: "::#{AnneAuth.configuration.admin_user_class_name.delete_prefix("::")}",
      inverse_of: :sessions
  end
end
