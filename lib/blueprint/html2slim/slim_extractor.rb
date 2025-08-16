require_relative 'slim_manipulator'

module Blueprint
  module Html2Slim
    class SlimExtractor < SlimManipulator
      def extract_file(file_path)
        content = read_file(file_path)
        structure = parse_slim_structure(content)

        # Handle different extraction modes
        sections_to_remove = []
        sections_to_keep = []

        extracted = if options[:outline]
                      extract_outline(structure, options[:outline])
                    elsif options[:selector]
                      extract_by_selector(structure, options[:selector])
                    else
                      # Original keep/remove logic
                      sections_to_remove = normalize_selectors(options[:remove] || [])
                      sections_to_keep = normalize_selectors(options[:keep] || [])

                      # Default removals if not keeping specific sections
                      if sections_to_keep.empty? && sections_to_remove.empty?
                        sections_to_remove = %w[doctype head nav header footer script]
                      end

                      # Extract content
                      extract_content(structure, sections_to_keep, sections_to_remove)
                    end

        # Remove wrapper if requested (not for outline mode)
        extracted = remove_outer_wrapper(extracted) if options[:remove_wrapper] && !options[:outline]

        # Rebuild the Slim content
        new_content = rebuild_extracted_content(extracted)

        # Write to output file
        output_path = options[:output] || file_path.sub(/\.slim$/, '_extracted.slim')
        write_file(output_path, new_content)

        # Build appropriate response based on extraction mode
        if options[:outline]
          {
            success: true,
            mode: 'outline',
            depth: options[:outline]
          }
        elsif options[:selector]
          {
            success: true,
            mode: 'selector',
            selector: options[:selector]
          }
        else
          {
            success: true,
            removed: sections_to_remove,
            kept: sections_to_keep.empty? ? nil : sections_to_keep
          }
        end
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def normalize_selectors(selectors)
        return [] unless selectors

        selectors.flat_map do |selector|
          selector.split(',').map(&:strip).map(&:downcase)
        end
      end

      def extract_content(structure, keep_selectors, remove_selectors)
        result = []
        skip_until_indent = nil
        keep_until_indent = nil

        structure.each_with_index do |item, _index|
          # If we're in skip mode, check if we've exited the skipped section
          if skip_until_indent
            next if item[:indent_level] > skip_until_indent

            skip_until_indent = nil
            # Continue processing this line

          end

          # If we're in keep mode, track when we exit
          keep_until_indent = nil if keep_until_indent && item[:indent_level] <= keep_until_indent

          # Determine what to do with this line
          if !keep_selectors.empty?
            # We have keep selectors - only keep matching sections
            if should_keep_line?(item, keep_selectors)
              # This line matches a keep selector
              keep_until_indent = item[:indent_level]
              result << item
            elsif keep_until_indent && item[:indent_level] > keep_until_indent
              # We're inside a kept section
              result << item
            end
            # Otherwise, skip this line
          elsif should_remove_line?(item, remove_selectors)
            # No keep selectors - use remove logic
            skip_until_indent = item[:indent_level]
            next
          # Skip this line and all its children
          else
            result << item
          end
        end

        result
      end

      def should_remove_line?(item, selectors)
        return false if selectors.empty?

        line = item[:stripped]

        selectors.any? do |selector|
          case selector
          when 'doctype'
            item[:type] == :doctype
          when 'script', 'style', 'link', 'meta'
            line.start_with?(selector)
          else
            # Check for element match or class/id match
            element_info = element_selector(line)
            if element_info
              element_info[:element] == selector ||
                element_info[:selector].include?(".#{selector}") ||
                element_info[:selector].include?("##{selector}")
            else
              false
            end
          end
        end
      end

      def should_keep_line?(item, selectors)
        return true if selectors.empty?

        line = item[:stripped]

        selectors.any? do |selector|
          element_info = element_selector(line)
          if element_info
            element_info[:element] == selector ||
              element_info[:selector].include?(".#{selector}") ||
              element_info[:selector].include?("##{selector}")
          else
            false
          end
        end
      end

      def remove_outer_wrapper(structure)
        return structure if structure.empty?

        # Find the minimum indentation level
        min_indent = structure.map { |item| item[:indent_level] }.min

        # If there's only one element at the minimum level, remove it
        root_elements = structure.select { |item| item[:indent_level] == min_indent }

        if root_elements.size == 1 && root_elements.first[:type] == :element
          # Remove the wrapper and decrease indentation of all children
          structure = structure[1..-1].map do |item|
            item[:indent_level] -= 1 if item[:indent_level] > min_indent
            item
          end
        end

        structure
      end

      def rebuild_extracted_content(structure)
        return '' if structure.empty?

        # Normalize indentation - find minimum and adjust
        min_indent = structure.map { |item| item[:indent_level] }.min || 0

        structure.map do |item|
          adjusted_indent = item[:indent_level] - min_indent
          indent_string(adjusted_indent) + item[:stripped]
        end.join("\n")
      end

      def extract_outline(structure, max_depth)
        result = []

        structure.each do |item|
          # Include items up to the specified depth
          result << item if item[:indent_level] < max_depth
        end

        result
      end

      def extract_by_selector(structure, selector)
        result = []
        in_selected_section = false
        selected_indent = nil

        # Parse the CSS selector
        selector_parts = parse_css_selector(selector)

        structure.each do |item|
          # Check if we're exiting a selected section
          if in_selected_section && selected_indent && item[:indent_level] <= selected_indent
            in_selected_section = false
            selected_indent = nil
          end

          # Check if this item matches the selector
          if !in_selected_section && matches_selector?(item, selector_parts)
            in_selected_section = true
            selected_indent = item[:indent_level]
            result << item
          elsif in_selected_section
            result << item
          end
        end

        result
      end

      def parse_css_selector(selector)
        # Support basic CSS selectors: element, #id, .class, element.class, element#id
        parts = {}

        # Handle complex selectors like div.container#main
        if selector =~ /^([a-z][a-z0-9]*)?([#.][\w\-#.]*)?$/i
          parts[:element] = ::Regexp.last_match(1)
          selector_part = ::Regexp.last_match(2)

          if selector_part
            # Extract ID
            parts[:id] = ::Regexp.last_match(1) if selector_part =~ /#([\w\-]+)/

            # Extract classes
            classes = selector_part.scan(/\.([\w\-]+)/).flatten
            parts[:classes] = classes unless classes.empty?
          end
        elsif selector.start_with?('#')
          # Just an ID
          parts[:id] = selector[1..-1]
        elsif selector.start_with?('.')
          # Just a class
          parts[:classes] = [selector[1..-1]]
        else
          # Just an element
          parts[:element] = selector
        end

        parts
      end

      def matches_selector?(item, selector_parts)
        line = item[:stripped]
        element_info = element_selector(line)

        return false unless element_info

        # Check element match
        return false if selector_parts[:element] && !(element_info[:element] == selector_parts[:element])

        # Check ID match
        return false if selector_parts[:id] && !element_info[:selector].include?("##{selector_parts[:id]}")

        # Check class matches
        if selector_parts[:classes]
          selector_parts[:classes].each do |cls|
            return false unless element_info[:selector].include?(".#{cls}")
          end
        end

        true
      end
    end
  end
end
