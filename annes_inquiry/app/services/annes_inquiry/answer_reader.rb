module AnnesInquiry
  class AnswerReader
    def initialize(submission)
      @answers = submission.answers.includes(:field, options: :field_option, attachments: { file_attachment: :blob }).index_by { |answer| answer.field.key }
    end

    def [](key)
      answer = @answers[key.to_s]
      return unless answer

      case answer.value_type
      when "single_choice" then ordered_options(answer).first&.value
      when "multiple_choice" then ordered_options(answer).map(&:value)
      when "attachment" then answer.attachments.to_a
      else answer["#{answer.value_type}_value"]
      end
    end

    def to_h
      @answers.keys.index_with { |key| self[key] }
    end

    def choice_labels(key)
      answer = @answers[key.to_s]
      answer ? ordered_options(answer).map(&:label) : []
    end

    private
      def ordered_options(answer)
        answer.options.map(&:field_option).sort_by { |option| [ option.position, option.id ] }
      end
  end
end
