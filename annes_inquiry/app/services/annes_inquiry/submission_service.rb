module AnnesInquiry
  class SubmissionService
    Result = Data.define(:submission, :input, :status, :replayed) do
      def success? = submission.present?
      def replayed? = replayed
    end
    class Conflict < StandardError; end
    class ReplayFound < StandardError
      attr_reader :submission
      def initialize(submission) = @submission = submission
    end

    def self.call(**options)
      new(**options).call
    end

    def initialize(form:, token:, identity:, raw_values:, context: nil, adapter: AnnesInquiry.configuration.adapters[form.key], time_zone: "UTC")
      @form, @token, @identity, @raw_values, @context, @adapter, @time_zone = form, token, identity, raw_values, context, adapter, time_zone
    end

    def call
      @data = data = SubmissionToken.verify(@token, form: @form, identity: @identity)
      @version = data && @form.versions.find_by(id: data["version_id"])
      @input = Input.new(@version || @form.versions.published.first, raw_values: @raw_values, adapter: @adapter, context: @context, time_zone: @time_zone)
      raise Conflict unless @version
      existing = find_existing
      return replay(existing) if existing
      return result(422) unless @input.valid?
      digest = payload_digest
      blobs = AnswerWriter.upload_files(@input.values)
      submission = nil
      form = Form.find(@form.id)
      completed = form.with_lock(requires_new: true) do
        existing = find_existing
        raise ReplayFound.new(existing) if existing
        raise Conflict unless form.enabled? && @version.reload.published?
        submission = Submission.create!(form_version: @version, request_key: data.fetch("request_key"), payload_digest: digest)
        AnswerWriter.call(submission, @input.values, blobs: blobs)
        @adapter.persist!(submission, @input.values, @context) if @adapter&.respond_to?(:persist!)
        if @adapter&.respond_to?(:deliver)
          notification = submission.notification_requests.create!(kind: "received")
          ActiveRecord.after_all_transactions_commit { NotificationDispatcher.call(notification.id) }
        end
        true
      end
      unless completed
        @input.errors.add(:base, "保存が取り消されました。入力内容を確認してください。")
        return result(422)
      end
      result(201, submission: submission)
    rescue ReplayFound => replay_found
      replay(replay_found.submission, already_validated: true)
    rescue ActiveRecord::RecordNotUnique
      existing = find_existing
      raise unless existing
      replay(existing, already_validated: true)
    rescue Conflict
      @input.errors.add(:base, "フォームが更新されたか、送信情報が無効です。フォームを開き直してください。")
      result(409)
    rescue ActiveRecord::RecordInvalid => error
      @input.errors.add(:base, error.record.errors.full_messages.to_sentence)
      result(422)
    end

    private
      def find_existing
        Submission.find_by(form_version_id: @version.id, request_key: @data.fetch("request_key"))
      end

      def replay(submission, already_validated: false)
        keys = @adapter&.respond_to?(:enrichment_keys) ? @adapter.enrichment_keys(@context).map(&:to_s) : []
        if keys.any?
          reader = AnswerReader.new(submission)
          @input = Input.new(@version, raw_values: @raw_values, adapter: @adapter, context: @context,
            time_zone: @time_zone, enrichment_values: keys.index_with { |key| reader[key] })
          already_validated = false
        end
        valid = already_validated || @input.valid?
        if !valid || submission.payload_digest != payload_digest
          @input.errors.add(:base, "同じ送信情報で内容を変更することはできません。新しいフォームを開いてください。")
          return result(409)
        end
        result(200, submission: submission, replayed: true)
      end

      def payload_digest
        context = @adapter&.respond_to?(:digest_context) ? @adapter.digest_context(@context) : {}
        PayloadDigest.call(@input.values, identity: @identity, context: context)
      end

      def result(status, submission: nil, replayed: false)
        Result.new(submission: submission, input: @input, status: status, replayed: replayed)
      end
  end
end
