module AnnesInquiry
  module Flows
    module Definitions
      class Validator
        def self.call(version)
          raise Error, "ステップを追加してください。" if version.steps.empty?
          version.steps.includes(form_version: :form).each do |step|
            raise Error, "有効な公開フォーム版を選択してください。" unless step.form_version.published? && step.form_version.form.enabled?
          end
        end
      end
    end
  end
end
