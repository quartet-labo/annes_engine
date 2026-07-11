# frozen_string_literal: true

require "pathname"
require "uri"

class DocumentationChecker
  Error = Data.define(:path, :line, :message) do
    def to_s
      location = line ? "#{path}:#{line}" : path.to_s
      "#{location}: #{message}"
    end
  end

  EXCLUDED_DIRECTORIES = %w[.docs .git node_modules tmp vendor].freeze
  INLINE_LINK_PATTERN = /!?\[[^\]]*\]\(([^)]+)\)/
  FENCE_PATTERN = /^\s*(`{3,}|~{3,})/

  def initialize(root:)
    @root = Pathname(root).expand_path
  end

  def call
    markdown_files.flat_map { |path| check_file(path) }
  end

  private
    attr_reader :root

    def markdown_files
      root.glob("**/*.md").reject do |path|
        path.relative_path_from(root).each_filename.any? do |part|
          EXCLUDED_DIRECTORIES.include?(part)
        end
      end.sort
    end

    def check_file(path)
      errors = []
      open_fence = nil

      path.each_line.with_index(1) do |line, line_number|
        if (marker = fence_marker(line))
          if open_fence.nil?
            open_fence = { character: marker[0], length: marker.length, line: line_number }
          elsif marker[0] == open_fence[:character] && marker.length >= open_fence[:length]
            open_fence = nil
          end
          next
        end

        next if open_fence

        line.scan(INLINE_LINK_PATTERN) do |match|
          target = normalize_link_target(match.first)
          next if target.nil? || external_target?(target)

          resolved = path.dirname.join(target).cleanpath
          next if resolved.exist?

          errors << Error.new(
            path.relative_path_from(root),
            line_number,
            "relative link target does not exist: #{target}"
          )
        end
      end

      if open_fence
        errors << Error.new(
          path.relative_path_from(root),
          open_fence[:line],
          "code fence is not closed"
        )
      end

      errors
    end

    def fence_marker(line)
      line.match(FENCE_PATTERN)&.captures&.first
    end

    def normalize_link_target(raw_target)
      target = raw_target.strip
      target = target[1...target.index(">")] if target.start_with?("<") && target.include?(">")
      target = target.split(/\s+["']/).first
      return target if external_target?(target)

      target = target.split("#", 2).first
      target = target.split("?", 2).first
      return if target.nil? || target.empty?

      URI::DEFAULT_PARSER.unescape(target)
    rescue URI::InvalidURIError
      target
    end

    def external_target?(target)
      target.start_with?("#", "/", "//") || target.match?(/\A[a-z][a-z0-9+.-]*:/i)
    end
end
