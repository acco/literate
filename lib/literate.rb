require 'literate/version'
require 'literate/config'
require 'fileutils'
require 'erb'
require 'ostruct'

module Literate

  class << self
    def extract_and_render(markdown_file_path, template_directory_path)

      if !File.exists?(markdown_file_path)
        if !markdown_file_path.match(/\.md$/)
          markdown_file_path += '.md'
        end
        if !File.exists?(markdown_file_path)
          raise "Error: Unable to find markdown file `#{markdown_file_path}`"
        end
      end

      if !File.exists?(template_directory_path)
        raise "Error: Unable to find template directory `#{template_directory_path}`"
      end

      ext = File.extname(template_directory_path)
      if !ext.empty? && ext != '.erb'
        raise 'Error: Template files must end with extension `.erb`'
      end

      blocks = []

      begin
        file = File.open(markdown_file_path, 'r')

        while (!file.eof?) do
          line = file.readline
          if line.match(/^\{.*lang=\'[^\']+\'.*\}$/)
            declaration_lineno = file.lineno
            vars = line.scan(/(\w+)=\'([^\']+)\'/).to_h
            values = vars.values_at('name', 'template', 'ver')
            if values.none?
              next
            elsif values.all?
              lines = []
              indent_level = Float::INFINITY
              while !file.eof && (line = file.readline) && (line.match(/^\s/) || line.empty?) do
                unless should_filter?(line)
                  unless line == "\n"
                    indent = line.scan(/^\s+/).first
                    if indent && !indent.empty?
                      indent_level = [indent.size, indent_level].min
                    end
                  end
                  lines << line
                end
              end
              unless indent_level == Float::INFINITY
                lines.map! do |line|
                  line.gsub(/^\s{#{indent_level}}/, '')
                end
              end
              if lines.empty?
                warn("Found a literate codeblock declared but nothing inside. (Line: #{declaration_lineno})")
              else
                blocks << CodeBlock.new(lines, values[0], values[1], values[2].to_i, declaration_lineno)
              end
            else
              warn("Found an incomplete literate codeblock declaration. (Line: #{declaration_lineno})")
              v = values.map { |v| '`' + v.inspect + '`' }.join(', ')
              warn("Got #{v} for `name`, `template`, `ver`")
            end
          end
        end
      ensure
        file.close
      end

      if blocks.empty?
        warn("No blocks found in file.")
        return
      end

      # Prune extraneous blocks
      pruned_blocks = []
      blocks.each do |block|
        dupe = pruned_blocks.detect do |b|
          [b.name, b.template, b.ver] == [block.name, block.template, block.ver]
        end
        if dupe
          warn("Found a duplicate block declaration. Skipping.")
          warn("\tExisting: #{dupe}")
          warn("\tSkipping: #{block}")
        else
          pruned_blocks << block
        end
      end

      # Render a template once for each version
      versions = pruned_blocks.map(&:ver).uniq.sort

      namespaces = {}

      (versions.min).upto(versions.max) do |version|
        blocks = pruned_blocks.select { |b| b.ver == version }

        templates = blocks.map(&:template).uniq

        templates.each do |template|
          namespaces[template] ||= TemplateNamespace.new
          namespace = namespaces[template]

          if template.match(/\.erb$/)
            template_file = File.join(template_directory_path, template)
          else
            template_candidates = Dir[File.join(template_directory_path, template + '.*.erb')]
            if template_candidates.size > 1
              warn("Found more than one possible template for `#{template}` in specified directory")
              warn("Matching files:")
              template_candidates.each_with_index do |c, i|
                warn("\t (%s) %s" % [i + 1, File.basename(c)])
              end
              warn("Continuing with (1). Rename conflicting templates or specify" +
                   "full template filename in declaration. (e.g. `template.js.erb`" +
                   " instead of `template`)")
            end
            template_file = template_candidates.first
          end

          if template_file.nil?
            error("Could not find template matching `#{template}` in:")
            error("\t#{template_directory_path}")
            next
          elsif !File.exists?(template_file)
            error("Could not find template:")
            error("\t#{template_file}")
            next
          end

          m = template_file.match(/(\.\w+)\.erb$/)
          extension_with_erb = m && m[0]
          extension = m && m[1]

          if extension.nil?
            error("Found an unexpected extension for a template file.")
            error("\tTemplate file must end with extension .*.erb")
            error("\te.g.: template.js.erb")
            raise "Unexpected extension found"
          end

          name = File.basename(template_file.gsub(/#{extension_with_erb}$/, ''))
          output_file = File.join(template_directory_path, name + "-#{version}" + extension)

          blocks_for_template = blocks.select { |b| b.template == template }

          namespace.merge(blocks_for_template)
          namespace.set_meta({'version' => version})
          t = File.open(template_file).read
          result = ERB.new(t).result(namespace.get_binding)
          File.open(output_file, 'w+') do |f|
            f.puts result
          end
          log("Wrote #{truncate_left(output_file, 50)}")
        end
      end

      log("Done.")
    end

    private

    def warn(text)
      l "%s: WARN: %s" % [Time.now, text]
    end

    def error(text)
      l "%s: ERROR: %s" % [Time.now, text]
    end

    def log(text)
      l "%s: %s" % [Time.now, text]
    end

    def l(text)
      unless ENV['TEST']
        STDERR.puts(text)
      end
    end

    class CodeBlock < Struct.new(:lines, :name, :template, :ver, :lineno)

      def blob
        lines.join
      end

      def to_s
        s = "<CodeBlock"
        to_h.each_pair do |k, v|
          unless k == :lines
            s += ' %s=%s' % [k, v]
          end
        end
        s += ' >'
      end
    end

    class TemplateNamespace

      def merge(blocks)
        blocks.each do |block|
          instance_variable_set('@' + block.name, block.blob)
        end
      end

      def set_meta(meta)
        @literate ||= OpenStruct.new
        @literate.meta = meta
      end

      def get_binding
        binding
      end
    end

    def truncate_left(str, chrs)
      if str.size <= chrs
        str
      else
        start = -(chrs + 1)
        '...' + str[start.. -1]
      end
    end

    def should_filter?(line)
      Config.filter_lines_matching.detect do |f|
        line.match(f)
      end
    end
  end
end
