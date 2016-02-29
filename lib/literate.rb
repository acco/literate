require 'literate/version'
require 'literate/config'
require 'fileutils'
require 'erb'
require 'ostruct'
require 'diffy'

module Literate

  class << self
    def extract_and_render(markdown_file_paths, template_directory_path)
      markdown_file_paths = [ markdown_file_paths ].flatten

      if !File.exists?(template_directory_path)
        raise "Error: Unable to find template directory `#{template_directory_path}`"
      end

      ext = File.extname(template_directory_path)
      if !ext.empty? && ext != '.erb'
        raise 'Error: Template files must end with extension `.erb`'
      end

      all_blocks = extract_blocks(markdown_file_paths)

      if all_blocks.empty?
        warn("No blocks found in file.")
        return
      end

      # Render a template once for each version
      versions = all_blocks.map(&:ver).uniq.sort

      namespaces = {}

      (versions.min).upto(versions.max) do |version|
        blocks = all_blocks.select { |b| b.ver == version }

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

    DIFF_HEADER_INSERT_OFFSET = '<div class="diff">'.size
    CSS_TEMPLATE_FILE = File.expand_path(File.join(__FILE__, '../', 'templates/diff.css.erb'))
    HTML_TEMPLATE_FILE = File.expand_path(File.join(__FILE__, '../', 'templates/diff.html.erb'))
    def extract_and_diff(markdown_file_paths, diff_out_file_path)
      markdown_file_paths = [ markdown_file_paths ].flatten
      if !File.exists?(diff_out_file_path)
        raise "Error: Invalid path `#{diff_out_file_path}`"
      end

      blocks = extract_blocks(markdown_file_paths, disable_filtering: true)

      if blocks.empty?
        warn("No blocks found in file.")
        return
      end

      blocks_by_name = blocks.group_by do |block|
        block.name
      end

      diffs = {}

      blocks_by_name.each do |name, blocks|
        blocks.sort_by! { |block| block.ver }
        if blocks.size > 1
          diffs[name] = []

          (1).upto(blocks.size-1).each do |n|
            a = blocks[n-1]
            b = blocks[n]
            diffs[name] << {
              ver_a: a.ver,
              ver_b: b.ver,
              html: diff(a.blob, b.blob)
            }
          end
        end
      end

      css_namespace = GenericNamespace.new({ css: Diffy::CSS })
      css_template = File.open(CSS_TEMPLATE_FILE).read
      css_out = ERB.new(css_template).result(css_namespace.get_binding)

      css_file_path = File.join(diff_out_file_path, 'diff.css')

      File.open(css_file_path, 'w+') do |f|
        f.write css_out
      end
      log("Wrote #{truncate_left(css_file_path, 50)}")

      html = diffs.inject("") do |memo, element|
        name, diffs = element
        memo += "\n<hr>\n"
        memo += "<h1>Diffs for #{name}<h1>"

        diffs.each do |diff|
          header = "Betwixt versions #{diff[:ver_a]} & #{diff[:ver_b]}"
          diff[:html].insert(DIFF_HEADER_INSERT_OFFSET, '<h4>' + header + '</h4>')
          memo += diff[:html]
        end
        memo
      end

      template = File.open(HTML_TEMPLATE_FILE).read
      paths = markdown_file_paths.map {|path| File.basename(path) }
      title = "Diffs for #{paths.join(', ')}"
      namespace = GenericNamespace.new({ html: html, title: title })
      diff_file_path = File.join(diff_out_file_path, "diffs.html")
      File.open(diff_file_path, 'w+') do |f|
        f.write ERB.new(template).result(namespace.get_binding)
      end
      log("Wrote #{truncate_left(diff_file_path, 50)}")
      log("CMD+CLICK to view:\n" + diff_file_path)
    end

    private

    def extract_blocks(markdown_file_paths, opts={})
      blocks = []

      markdown_file_paths.each do |markdown_file_path|

        if !File.exists?(markdown_file_path)
          if !markdown_file_path.match(/\.md$/)
            markdown_file_path += '.md'
          end
          if !File.exists?(markdown_file_path)
            raise "Error: Unable to find markdown file `#{markdown_file_path}`"
          end
        end

        begin
          file = File.open(markdown_file_path, 'r')
          filename = File.basename(markdown_file_path)

          while (!file.eof?) do
            line = file.readline
            if line.match(/^\{.*lang=[\'|\w]+.*\}$/)
              declaration_lineno = file.lineno
              vars = line.scan(/([\w|\-]+)=\'?(\w+)\'?/).to_h
              values = vars.values_at('name', 'template', 'ver')
              if values.none?
                next
              elsif values.all?
                lines = []
                indent_level = Float::INFINITY
                while !file.eof && (line = file.readline) && (line.match(/^\s/) || line.empty?) do
                  if opts[:disable_filtering] || keep_line?(line)
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
                  blocks << CodeBlock.new(
                    lines, values[0], values[1], values[2].to_i,
                    declaration_lineno, filename
                  )
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

      return pruned_blocks
    end

    def diff(a, b)
      Diffy::Diff.new(a, b).to_s(:html_simple)
    end

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

    class CodeBlock < Struct.new(:lines, :name, :template, :ver, :lineno, :filename)

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

    def keep_line?(line)
      !Config.filter_lines_matching.detect do |f|
        line.match(f)
      end
    end

    class GenericNamespace
      def initialize(hash)
        set(hash)
      end

      def get_binding
        binding
      end

      private

      def set(hash)
        hash.each do |k, v|
          instance_variable_set('@' + k.to_s, v)
        end
      end
    end
  end
end
