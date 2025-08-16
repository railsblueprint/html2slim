module Blueprint
  module Html2Slim
    class SlimManipulator
      attr_reader :options

      def initialize(options = {})
        @options = options
        @indent_size = options[:indent_size] || 2
      end

      protected

      def read_file(file_path)
        File.read(file_path, encoding: 'UTF-8')
      end

      def write_file(file_path, content)
        return if options[:dry_run]

        # Create backup if requested
        if options[:backup]
          backup_path = "#{file_path}.bak"
          File.write(backup_path, read_file(file_path), encoding: 'UTF-8')
        end

        # Ensure content ends with newline
        content += "\n" unless content.end_with?("\n")
        File.write(file_path, content, encoding: 'UTF-8')
      end

      def parse_slim_structure(content)
        lines = content.split("\n")
        structure = []

        lines.each_with_index do |line, index|
          indent_level = line[/\A */].size / @indent_size
          stripped = line.strip

          next if stripped.empty?

          structure << {
            line: line,
            stripped: stripped,
            indent_level: indent_level,
            line_number: index + 1,
            type: detect_line_type(stripped)
          }
        end

        structure
      end

      def detect_line_type(line)
        case line
        when /^doctype/i
          :doctype
        when %r{^/!}
          :html_comment
        when %r{^/\s}
          :slim_comment
        when /^-/
          :ruby_code
        when /^=/
          :ruby_output
        when /^ruby:/
          :ruby_block
        when /^\|/
          :text_pipe
        when /^[#.]/
          :div_shorthand
        when /^[a-z][a-z0-9]*/i
          :element
        else
          :text
        end
      end

      def indent_string(level)
        ' ' * (@indent_size * level)
      end

      def rebuild_slim(structure)
        structure.map do |item|
          item[:modified_line] || item[:line]
        end.join("\n")
      end

      def element_selector(line)
        # Extract element, id, and classes from a Slim line
        match = line.match(/^([a-z][a-z0-9]*)?([#.][\w\-#.]*)?/i)
        return nil unless match

        {
          element: match[1] || 'div',
          selector: match[2] || '',
          full: match[0]
        }
      end

      def has_slash_prefix_text?(line)
        # Check if line has text that starts with forward slash
        # This is a common issue that needs fixing
        stripped = line.strip

        # Check for inline text after element
        if stripped =~ /^[a-z#.]/i
          # Extract the text part after element definition
          text_part = stripped.sub(/^[a-z][a-z0-9]*([#.][\w\-#.]*)?(\[.*?\])?/i, '').strip
          return text_part.start_with?('/')
        end

        # Check for standalone text that starts with slash
        stripped.start_with?('/') && !stripped.start_with?('/!') && !stripped.match?(%r{^/\s})
      end
    end
  end
end
