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
                        sections_to_remove = %w[doctype html head nav header footer script body]
                      end

                      # Extract content
                      extract_content(structure, sections_to_keep, sections_to_remove)
                    end

        # Remove wrapper if requested (not for outline mode)
        extracted = remove_outer_wrapper(extracted) if options[:remove_wrapper] && !options[:outline]

        # Clean up orphaned comments
        extracted = clean_orphaned_comments(extracted)

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
        @current_structure = structure # Store for parent lookup
        
        # Parse the CSS selector
        selector_parts = parse_css_selector(selector)

        # For child selectors like "body > section", find all matching sections
        if selector_parts[:combinator] == :child
          structure.each do |item|
            if matches_selector?(item, selector_parts)
              # Add this item and all its children
              result << item
              # Add children until we hit the same or lower indent level
              item_index = structure.index(item)
              next unless item_index
              
              (item_index + 1...structure.size).each do |i|
                child_item = structure[i]
                break if child_item[:indent_level] <= item[:indent_level]
                result << child_item
              end
            end
          end
        else
          # Original single-section logic for simple selectors
          in_selected_section = false
          selected_indent = nil

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
        end

        result
      end

      def parse_css_selector(selector)
        # Support CSS selectors: element, #id, .class, element.class, element#id
        # Also support child combinator: parent > child
        parts = {}

        # Handle child combinator (e.g., "body > section")
        if selector.include?(' > ')
          parent_child = selector.split(' > ').map(&:strip)
          if parent_child.size == 2
            parts[:parent] = parse_simple_selector(parent_child[0])
            parts[:child] = parse_simple_selector(parent_child[1])
            parts[:combinator] = :child
            return parts
          end
        end

        # Handle simple selectors
        parts.merge!(parse_simple_selector(selector))
        parts
      end

      def parse_simple_selector(selector)
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
        # Handle child combinator selectors
        if selector_parts[:combinator] == :child
          return matches_child_selector?(item, selector_parts)
        end

        # Handle simple selectors
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

      def matches_child_selector?(item, selector_parts)
        # For child selector, we need to check if this item matches the child
        # and verify its parent matches the parent selector
        
        # First check if this item matches the child selector
        return false unless matches_simple_selector?(item, selector_parts[:child])

        # Then find its parent and check if it matches the parent selector
        parent_item = find_parent_item(item)
        return false unless parent_item

        matches_simple_selector?(parent_item, selector_parts[:parent])
      end

      def matches_simple_selector?(item, selector_parts)
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

      def find_parent_item(target_item)
        # Find the parent of the target item by looking for the previous item
        # with lower indentation level
        target_indent = target_item[:indent_level]
        target_line_num = target_item[:line_number]
        
        # Search backwards from target item to find parent
        return nil unless @current_structure
        
        @current_structure.reverse.each do |item|
          next if item[:line_number] >= target_line_num
          
          if item[:indent_level] < target_indent
            return item
          end
        end
        
        nil
      end

      def clean_orphaned_comments(structure)
        result = []
        
        structure.each_with_index do |item, index|
          # If this is a comment, check if the next non-comment item exists
          if item[:type] == :html_comment
            # Look ahead to see if there's meaningful content after this comment
            has_following_content = false
            
            (index + 1...structure.size).each do |next_index|
              next_item = structure[next_index]
              
              # If we find content at the same or lower indent level, keep the comment
              if next_item[:indent_level] <= item[:indent_level] && 
                 next_item[:type] != :html_comment
                has_following_content = true
                break
              end
              
              # If we find indented content, keep the comment
              if next_item[:indent_level] > item[:indent_level]
                has_following_content = true
                break
              end
            end
            
            # Only keep the comment if there's following content
            result << item if has_following_content
          else
            result << item
          end
        end
        
        result
      end
    end
  end
end
