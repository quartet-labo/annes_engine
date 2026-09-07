module AnnesInquiry
  class AttachmentValidator
    Upload = Data.define(:upload, :checksum, :byte_size, :filename, :content_type)

    def self.call(field, files, errors)
      if field.max_files && files.size > field.max_files
        errors.add(field.key, "は#{field.max_files}件以下にしてください")
        return []
      end
      files.filter_map do |file|
        unless file.is_a?(ActionDispatch::Http::UploadedFile)
          errors.add(field.key, "はファイルを選択してください")
          next
        end
        io = file.tempfile
        size = io.size
        errors.add(field.key, "に空のファイルは添付できません") if size.zero?
        if field.max_file_bytes && size > field.max_file_bytes
          errors.add(field.key, "のファイルサイズが上限を超えています")
          next
        end
        filename = ActiveStorage::Filename.new(file.original_filename).to_s
        extension = File.extname(filename).downcase
        magic_type = Marcel::MimeType.for(io)
        named_type = Marcel::MimeType.for(name: filename)
        mime = if magic_type == "application/octet-stream"
          named_type.start_with?("text/") && valid_text?(io) ? named_type : magic_type
        else
          Marcel::MimeType.for(io, name: filename)
        end
        mime = "application/octet-stream" if mime.start_with?("text/") && !valid_text?(io)
        permitted = field.file_types.any? { |rule| rule.extension == extension && (rule.content_type.blank? || rule.content_type == mime) }
        errors.add(field.key, "のファイル形式は許可されていません") unless permitted
        io.rewind
        checksum = Digest::SHA256.new
        while (chunk = io.read(64 * 1024))
          checksum.update(chunk)
        end
        io.rewind
        Upload.new(upload: file, checksum: checksum.hexdigest, byte_size: size, filename: filename, content_type: mime)
      end
    end

    def self.valid_text?(io)
      io.rewind
      converter = Encoding::Converter.new("UTF-8", "UTF-16LE")
      while (chunk = io.read(64 * 1024))
        return false if chunk.include?("\0")
        converter.convert(chunk)
      end
      converter.finish
      true
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      false
    ensure
      io.rewind
    end
    private_class_method :valid_text?
  end
end
