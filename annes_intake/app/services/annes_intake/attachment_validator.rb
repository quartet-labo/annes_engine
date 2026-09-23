module AnnesIntake
  class AttachmentValidator
    Upload = Data.define(:upload, :checksum, :byte_size, :filename, :content_type)
    def self.call(field, files, errors)
      originals = {}
      sources = files.map do |file|
        next file unless file.is_a?(ActionDispatch::Http::UploadedFile)
        source = AnnesFormKit::UploadSource.new(io: -> { file.tempfile }, filename: file.original_filename)
        originals[source.object_id] = file
        source
      end
      result = AnnesFormKit::AttachmentInspector.call(field: Definitions::SchemaAdapter.field(field), uploads: sources)
      result.errors.each { |key, messages| messages.each { |message| errors.add(key, message) } }
      result.values.map { |value| Upload.new(upload: originals.fetch(value.source.object_id), checksum: value.checksum,
        byte_size: value.byte_size, filename: value.filename, content_type: value.content_type) }
    end
  end
end
