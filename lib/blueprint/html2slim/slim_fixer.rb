require_relative 'slim_manipulator'

module Blueprint
  module Html2Slim
    class SlimFixer < SlimManipulator
      def fix_file(file_path)
        content = read_file(file_path)
        original_content = content.dup

        fixes_applied = []

        if options[:fix_slashes] != false
          content, slash_fixes = fix_slash_prefix(content)
          fixes_applied.concat(slash_fixes)
        end

        if options[:fix_multiline] != false
          content, multiline_fixes = fix_multiline_text(content)
          fixes_applied.concat(multiline_fixes)
        end

        if options[:dry_run]
          if fixes_applied.any?
            puts "\nChanges that would be made to #{file_path}:"
            puts "  Fixes: #{fixes_applied.join(", ")}"
            show_diff(original_content, content) if options[:verbose]
          else
            puts "No issues found in #{file_path}"
          end
        elsif content != original_content
          write_file(file_path, content)
        end

        { success: true, fixes: fixes_applied }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def fix_slash_prefix(content)
        fixes = []
        lines = content.split("\n")

        lines.map!.with_index do |line, index|
          stripped = line.strip
          indent = line[/\A */]

          # Fix text that starts with / after an element
          if stripped =~ %r{^([a-z#.][^\s/]*)\s+(/[^/].*)$}i
            element_part = ::Regexp.last_match(1)
            text_part = ::Regexp.last_match(2)

            # Convert to pipe notation
            new_lines = [
              "#{indent}#{element_part}",
              "#{indent}#{" " * @indent_size}| #{text_part}"
            ]

            fixes << "slash text at line #{index + 1}"
            new_lines
          # Fix standalone text starting with slash (not a comment)
          elsif stripped.start_with?('/') && !stripped.start_with?('/!') && !stripped.match?(%r{^/\s})
            fixes << "slash text at line #{index + 1}"
            "#{indent}| #{stripped}"
          else
            line
          end
        end

        lines.flatten!
        new_content = lines.join("\n")

        [new_content, fixes]
      end

      def fix_multiline_text(content)
        fixes = []
        lines = content.split("\n")
        result_lines = []
        i = 0

        while i < lines.size
          line = lines[i]
          stripped = line.strip
          indent = line[/\A */]

          # Check if this is an element with multiline text content
          if stripped =~ /^([a-z#.][^\s]*)\s+(.+)$/i && i + 1 < lines.size
            element_part = ::Regexp.last_match(1)
            first_text = ::Regexp.last_match(2)

            # Look ahead to see if next lines are continuation text
            next_line_indent = lines[i + 1][/\A */]

            if next_line_indent.size > indent.size && !lines[i + 1].strip.empty?
              # This looks like multiline text that should use pipe notation
              text_lines = [first_text]
              j = i + 1

              while j < lines.size
                next_indent = lines[j][/\A */]
                next_stripped = lines[j].strip

                # Stop if we hit a line with same or less indentation
                break if next_indent.size <= indent.size
                # Stop if we hit Slim syntax
                break if next_stripped =~ %r{^[=\-|/!#.]} || next_stripped =~ /^[a-z]+[#.\[]/i

                text_lines << next_stripped
                j += 1
              end

              if text_lines.size > 1
                # Convert to proper multiline with pipes
                result_lines << "#{indent}#{element_part}"
                text_lines.each do |text|
                  result_lines << "#{indent}#{" " * @indent_size}| #{text}"
                end

                fixes << "multiline text at line #{i + 1}"
                i = j
                next
              end
            end
          end

          result_lines << line
          i += 1
        end

        new_content = result_lines.join("\n")
        [new_content, fixes]
      end

      def show_diff(original, modified)
        puts "\n--- Original ---"
        puts original
        puts "\n+++ Modified +++"
        puts modified
        puts
      end
    end
  end
end
