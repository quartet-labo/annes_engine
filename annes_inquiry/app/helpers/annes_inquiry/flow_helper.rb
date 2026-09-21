module AnnesInquiry
  module FlowHelper
    def flow_operation_token(run, action, context)
      Flows::OperationToken.issue(run: run, action: action, context: context)
    rescue Flows::Forbidden
      nil
    end

    def flow_value(value)
      case value
      when Array then value.map { |item| item.respond_to?(:file) ? item.file.filename.to_s : item.to_s }.join("、")
      when true then "はい"
      when false then "いいえ"
      when nil then "未回答"
      else value.to_s
      end
    end

    def flow_step_status(step)
      {"draft" => "入力中", "complete" => "入力済み", "inactive" => "対象外"}.fetch(step.status)
    end
  end
end
