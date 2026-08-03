module AnneAudit
  class Context
    class << self
      def current
        ActiveSupport::IsolatedExecutionState[:anne_audit_context] ||= {}
      end

      def with(values)
        previous = current
        ActiveSupport::IsolatedExecutionState[:anne_audit_context] = previous.merge(values.compact)
        yield
      ensure
        ActiveSupport::IsolatedExecutionState[:anne_audit_context] = previous
      end
    end
  end
end
