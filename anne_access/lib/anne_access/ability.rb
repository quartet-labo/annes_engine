module AnneAccess
  class Ability
    attr_reader :principal, :action_mapper

    def initialize(principal, action_mapper: ActionMapper.new)
      @principal = principal
      @action_mapper = action_mapper
    end

    def can?(action, resource, record: nil)
      normalized_action = action_mapper.map(action)
      normalized_resource = normalize_resource(resource)
      allowed = allowed_by_role?(normalized_action, normalized_resource)

      apply_custom_rule(
        principal:,
        action: normalized_action,
        resource: normalized_resource,
        record:,
        allowed:
      )
    end

    private
      def allowed_by_role?(action, resource)
        return false unless valid_principal?
        return false if action.blank? || resource.blank?
        return true if super_admin?

        role_ids = assigned_role_ids
        return false if role_ids.empty?
        permitted_actions = [ action ]
        permitted_actions << "manage" if action_mapper.standard?(action)

        Permission
          .joins(:role_permissions)
          .where(anne_access_role_permissions: { role_id: role_ids })
          .where(resource:)
          .where(action: permitted_actions)
          .exists?
      end

      def valid_principal?
        principal.present? && principal.respond_to?(:id) && principal.id.present?
      end

      def super_admin?
        super_admin_role_keys = Array(AnneAccess.configuration.super_admin_role_keys).map(&:to_s)
        return false if super_admin_role_keys.empty?

        Role.where(id: assigned_role_ids, key: super_admin_role_keys).exists?
      end

      def assigned_role_ids
        @assigned_role_ids ||= begin
          ids = Assignment.where(principal:).pluck(:role_id)
          default_role = default_role_id
          default_role ? (ids + [ default_role ]).uniq : ids
        end
      end

      def default_role_id
        default_role_key = AnneAccess.configuration.default_role_key
        return if default_role_key.blank?

        Role.find_by(key: default_role_key.to_s)&.id
      end

      def normalize_resource(resource)
        resource.to_s.strip.downcase
      end

      def apply_custom_rule(principal:, action:, resource:, record:, allowed:)
        custom_rule = AnneAccess.configuration.custom_rule
        return allowed unless custom_rule

        custom_rule.call(principal:, action:, resource:, record:, allowed:)
      end
  end
end
