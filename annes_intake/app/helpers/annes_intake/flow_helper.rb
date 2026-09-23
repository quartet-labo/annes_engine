module AnnesIntake
  module FlowHelper
    def flow_operation_token(run, action, context)
      Flows::OperationToken.issue(run: run, action: action, context: context)
    rescue Flows::Forbidden
      nil
    end

    def intake_mapped_value(step, field)
      @intake_mapped_values ||= Flows::RouteEvaluator.raw_values(step)
      flow_value(ValueConverter.call(field, @intake_mapped_values[field.key]), field: field)
    rescue ArgumentError
      "未回答"
    end

    def flow_value(value, field:)
      value = value.map { |item| item.respond_to?(:file) ? item.file.filename.to_s : item } if value.is_a?(Array)
      AnnesFormKit::ValuePresenter.call(field: Definitions::SchemaAdapter.field(field), value: value, time_zone: Time.zone.name)
    end

    def intake_time(value)
      value.in_time_zone.strftime("%Y/%m/%d %H:%M %Z")
    end

    def intake_notification_event(notification)
      return "追加質問の発行" if notification.event_key.start_with?("follow_up:")
      {"received" => "初回受付", "answered" => "追加回答の受付"}.fetch(notification.event_key, "通知")
    end

    def follow_up_allowed?(action, root)
      Flows::AccessPolicy.for_run(root, @context).authorize!(action, run: root)
    rescue Flows::Forbidden, ActiveRecord::RecordNotFound
      false
    end

    def follow_up_status(request)
      return "取消済み" if request.cancelled?
      return "回答済み" if request.answered?
      return "期限切れ" if request.expired?
      request.draft? ? "準備中" : "回答待ち"
    end

    def run_status(run)
      {"in_progress" => "入力中", "submitted" => "受付済み", "cancelled" => "取消済み", "expired" => "期限切れ"}.fetch(run.status)
    end
    def version_status(version)
      {"draft" => "下書き", "published" => "公開中", "retired" => "過去の版"}.fetch(version.status)
    end

    def step_status(step)
      {"draft" => "入力中", "complete" => "入力済み", "inactive" => "対象外"}.fetch(step.status)
    end
  end
end
