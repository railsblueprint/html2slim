require_relative 'slim_manipulator'

module Blueprint
  module Html2Slim
    class SlimValidator < SlimManipulator
      def validate_file(file_path)
        content = read_file(file_path)
        structure = parse_slim_structure(content)

        errors = []
        warnings = []

        # Check for syntax errors
        syntax_errors = check_syntax_errors(structure)
        errors.concat(syntax_errors)

        # Check for common issues that might cause problems
        potential_issues = check_potential_issues(structure)
        warnings.concat(potential_issues)

        # Rails-specific checks if requested
        if options[:check_rails]
          rails_issues = check_rails_conventions(structure)
          warnings.concat(rails_issues)
        end

        # Try to parse with Slim if available
        if defined?(Slim)
          begin
            Slim::Template.new { content }
          rescue StandardError => e
            errors << "Slim parsing error: #{e.message}"
          end
        end

        {
          valid: errors.empty?,
          errors: errors,
          warnings: warnings
        }
      rescue StandardError => e
        {
          valid: false,
          errors: ["Failed to read or validate file: #{e.message}"],
          warnings: []
        }
      end

      private

      def check_syntax_errors(structure)
        errors = []
        indent_stack = [-1]

        structure.each_with_index do |item, _index|
          line = item[:stripped]
          indent = item[:indent_level]
          line_num = item[:line_number]

          # Check indentation consistency
          if indent > indent_stack.last + 1
            errors << "Line #{line_num}: Invalid indentation jump (expected #{indent_stack.last + 1}, got #{indent})"
          end

          # Update indent stack
          indent_stack.pop while indent_stack.last > indent
          indent_stack << indent if indent > indent_stack.last

          # Check for invalid syntax patterns
          if line.start_with?('/') && !line.match?(%r{^/[!|\s]})
            msg = "Line #{line_num}: Forward slash will be interpreted as comment. "
            errors << "#{msg}Use pipe notation for text: | #{line}"
          end

          # Check for text after element that starts with slash
          if line =~ %r{^([a-z#.][^\s]*)\s+(/[^/].*)$}i
            errors << "Line #{line_num}: Forward slash will be interpreted as comment. Use pipe notation for text"
          end

          # Check for unclosed brackets in attributes
          if line.include?('[') && !line.include?(']')
            errors << "Line #{line_num}: Unclosed attribute bracket"
          elsif line.include?(']') && !line.include?('[')
            errors << "Line #{line_num}: Unexpected closing bracket"
          end

          # Check for invalid Ruby code markers
          errors << "Line #{line_num}: Ruby code marker without code" if line =~ /^[=-]\s*$/

          # Check for mixed tabs and spaces (if strict mode)
          if options[:strict] && item[:line].match?(/\t/)
            errors << "Line #{line_num}: Contains tabs (use spaces for indentation)"
          end
        end

        errors
      end

      def check_potential_issues(structure)
        warnings = []

        structure.each do |item|
          line = item[:stripped]
          line_num = item[:line_number]

          # Warn about text that might be misinterpreted
          warnings << "Line #{line_num}: Text containing '/' might need pipe notation" if line =~ %r{^\w+.*\s/\w+}

          # Warn about very long lines
          warnings << "Line #{line_num}: Line exceeds 120 characters" if item[:line].length > 120

          # Warn about deprecated Slim syntax
          warnings << "Line #{line_num}: Single quote for text interpolation is deprecated" if line.start_with?("'")

          # Warn about potential multiline text issues
          if line =~ /^[a-z#.][^\s]*\s+[^=\-|].{50,}/i
            warnings << "Line #{line_num}: Long inline text might be better as multiline with pipe notation"
          end

          # Warn about inline styles (if strict)
          if options[:strict] && line.include?('style=')
            warnings << "Line #{line_num}: Inline styles detected (consider using classes)"
          end
        end

        warnings
      end

      def check_rails_conventions(structure)
        warnings = []

        structure.each do |item|
          line = item[:stripped]
          line_num = item[:line_number]

          # Check for static asset links that should use Rails helpers
          if line =~ /link.*href=["'].*\.(css|scss)/
            warnings << "Line #{line_num}: Consider using stylesheet_link_tag for CSS files"
          end

          if line =~ /script.*src=["'].*\.js/
            warnings << "Line #{line_num}: Consider using javascript_include_tag for JS files"
          end

          # Check for static image paths
          if line =~ %r{img.*src=["'](?!http|//)}
            warnings << "Line #{line_num}: Consider using image_tag helper for images"
          end

          # Check for forms without Rails helpers
          if line.start_with?('form') && !line.include?('form_for') && !line.include?('form_with')
            warnings << "Line #{line_num}: Consider using Rails form helpers (form_for, form_with)"
          end

          # Check for missing CSRF token in forms
          if line =~ /^form\[.*method=["'](post|patch|put|delete)/i
            warnings << "Line #{line_num}: Ensure CSRF token is included in form"
          end

          # Check for hardcoded URLs
          if line =~ %r{href=["']/(users|posts|articles|products)}
            warnings << "Line #{line_num}: Consider using Rails path helpers instead of hardcoded URLs"
          end
        end

        warnings
      end
    end
  end
end
