require 'yaml'

module Literate
  class Config
    class << self
      def filter_lines_matching
        @filter_lines_matching ||= begin
          f = config['filter_lines_matching'] || []
          f.map! { |m| Regexp.new(m) }
          if filter_leanpub_code_comments
            f << /^\s*\<\!\-\-\s*leanpub/
          end
          f
        end
      end

      def filter_leanpub_code_comments
        c = config['filter_leanpub_code_comments']
        c.nil? ? true : c
      end

      def config_file=(config_file)
        @config = nil
        @filter_lines_matching = nil
        @config_file = config_file
      end

      private

      def config
        return @config if @config

        if @config_file.nil?
          dir = Dir.pwd

          depth = 0
          while (depth += 1) && (depth < 5) do
            path = File.join(dir, '.literaterc')
            if File.exists?(path)
              @config_file = path
              break
            elsif dir == File.expand_path('~/')
              break
            else
              dir = File.expand_path(File.join(dir, '../'))
            end
          end
        elsif !File.exists?(@config_file)
          raise "Config file `#{@config_file}` not found"
        end

        if @config_file
          @config = YAML.load_file(@config_file)
        end
        @config ||= {}
      end
    end
  end
end
