module AnnesInquiry
  class SubmissionToken
    def self.issue(version, identity:, expires_in: 2.hours, request_key: SecureRandom.uuid)
      verifier.generate({ "form_id" => version.form_id, "version_id" => version.id,
        "request_key" => request_key, "identity" => Digest::SHA256.hexdigest(identity) }, expires_in: expires_in)
    end

    def self.verify(token, form:, identity:)
      return unless token.is_a?(String) && identity.is_a?(String)
      data = verifier.verified(token)
      valid = data.is_a?(Hash) && data["form_id"] == form.id && data["identity"] == Digest::SHA256.hexdigest(identity) &&
        data["request_key"].is_a?(String) && data["request_key"].match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)
      valid ? data : nil
    end

    def self.verifier
      Rails.application.message_verifier("annes-inquiry-submission-v1")
    end
    private_class_method :verifier
  end
end
