module AnneAccess
  class Configuration
    DEFAULT_ACTION_ALIASES = {
      index: :read,
      show: :read,
      new: :create,
      edit: :update
    }.freeze

    attr_accessor :principal_class_names, :super_admin_role_keys, :default_role_key, :action_aliases, :custom_rule

    def initialize
      @principal_class_names = []
      @super_admin_role_keys = []
      @default_role_key = nil
      @action_aliases = DEFAULT_ACTION_ALIASES.dup
      @custom_rule = nil
    end
  end
end
