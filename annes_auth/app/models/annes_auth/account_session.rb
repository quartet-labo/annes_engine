module AnnesAuth
  class AccountSession < ApplicationRecord
    self.table_name = AnnesAuth.configuration.account_session_table_name

    belongs_to :account,
      class_name: AnnesAuth.configuration.account_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      inverse_of: :account_sessions

    validates :expires_at, presence: true

    scope :active, -> { where("expires_at > ?", Time.current) }

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    def record_use!
      touch(:last_used_at)
    end
  end
end
