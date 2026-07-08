module AnneAuth
  class Session < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :user,
      class_name: "::#{AnneAuth.configuration.user_class_name.delete_prefix("::")}",
      foreign_key: AnneAuth.configuration.session_user_foreign_key,
      inverse_of: :sessions

    belongs_to :admin_user,
      class_name: "::#{AnneAuth.configuration.admin_user_class_name.delete_prefix("::")}",
      foreign_key: AnneAuth.configuration.admin_session_user_foreign_key,
      optional: true
  end
end
