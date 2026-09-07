require "test_helper"

paths = ARGV.empty? ? Dir["test/**/*_test.rb"].reject { |path| path.start_with?("test/system/") } : ARGV.flat_map { |path| Dir[path] }
abort "No inquiry tests selected" if paths.empty?
ARGV.clear
paths.sort.each { |path| require File.expand_path(path) }
