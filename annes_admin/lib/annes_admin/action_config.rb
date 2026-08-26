module AnnesAdmin
  class ActionConfig
    attr_reader :name, :method, :scope, :label, :confirm, :block

    def initialize(name, method:, scope:, label:, confirm:, block:)
      @name = name.to_s
      @method = method.to_sym
      @scope = scope.to_sym
      @label = label.presence || name.to_s.humanize
      @confirm = confirm
      @block = block
    end

    def member?
      scope == :member
    end

    def collection?
      scope == :collection
    end

    def call(record:, controller:, resource:)
      block&.call(record:, controller:, resource:)
    end
  end
end
