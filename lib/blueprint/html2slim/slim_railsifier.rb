require_relative 'slim_manipulator'
require 'json'

module Blueprint
  module Html2Slim
    class SlimRailsifier < SlimManipulator
      def railsify_file(file_path)
        content = read_file(file_path)
        original_content = content.dup
        conversions = []

        # Load custom mappings if provided
        @custom_mappings = load_custom_mappings if options[:mappings]

        if options[:add_helpers] != false
          content, link_conversions = convert_links_to_helpers(content)
          conversions.concat(link_conversions)
        end

        if options[:use_assets] != false
          content, asset_conversions = convert_assets_to_pipeline(content)
          conversions.concat(asset_conversions)
        end

        if options[:add_csrf]
          content, csrf_additions = add_csrf_protection(content)
          conversions.concat(csrf_additions)
        end

        if options[:dry_run]
          if conversions.any?
            puts "\nChanges that would be made to #{file_path}:"
            puts "  Conversions: #{conversions.join(", ")}"
            show_diff(original_content, content) if options[:verbose]
          else
            puts "No Rails conversions needed for #{file_path}"
          end
        elsif content != original_content
          write_file(file_path, content)
        end

        { success: true, conversions: conversions }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def load_custom_mappings
        return {} unless options[:mappings] && File.exist?(options[:mappings])

        begin
          content = File.read(options[:mappings])
          if options[:mappings].end_with?('.json')
            JSON.parse(content)
          elsif options[:mappings].end_with?('.yml', '.yaml')
            require 'yaml'
            YAML.load_file(options[:mappings])
          else
            # Try to parse as JSON by default
            JSON.parse(content)
          end
        rescue StandardError => e
          puts "Warning: Failed to load mappings from #{options[:mappings]}: #{e.message}"
          {}
        end
      end

      def convert_links_to_helpers(content)
        conversions = []
        lines = content.split("\n")

        lines.map!.with_index do |line, index|
          if line =~ /^(\s*)a\[href="([^"]+)"([^\]]*)\](.*)/
            indent = ::Regexp.last_match(1)
            href = ::Regexp.last_match(2)
            attrs = ::Regexp.last_match(3)
            text = ::Regexp.last_match(4).strip

            # Convert known static paths to Rails helpers (only if mappings provided)
            rails_path = path_to_rails_helper(href)
            if rails_path
              conversions << "link at line #{index + 1}"
              "#{indent}= link_to \"#{text}\", #{rails_path}#{format_link_options(attrs)}"
            else
              line
            end
          else
            line
          end
        end

        [lines.join("\n"), conversions]
      end

      def convert_assets_to_pipeline(content)
        conversions = []
        lines = content.split("\n")

        lines.map!.with_index do |line, index|
          # Convert stylesheet links
          if line =~ /^(\s*)link\[.*href="([^"]+\.css[^"]*)"/
            indent = ::Regexp.last_match(1)
            href = ::Regexp.last_match(2)

            if !href.start_with?('http') && !href.start_with?('//')
              asset_name = File.basename(href, '.*')
              conversions << "stylesheet at line #{index + 1}"
              "#{indent}= stylesheet_link_tag '#{asset_name}'"
            else
              line
            end
          # Convert script tags
          elsif line =~ /^(\s*)script\[.*src="([^"]+\.js[^"]*)"/
            indent = ::Regexp.last_match(1)
            src = ::Regexp.last_match(2)

            if !src.start_with?('http') && !src.start_with?('//')
              asset_name = File.basename(src, '.*')
              conversions << "javascript at line #{index + 1}"
              "#{indent}= javascript_include_tag '#{asset_name}'"
            else
              line
            end
          # Convert image tags
          elsif line =~ /^(\s*)img\[src="([^"]+)"([^\]]*)\]/
            indent = ::Regexp.last_match(1)
            src = ::Regexp.last_match(2)
            attrs = ::Regexp.last_match(3)

            if !src.start_with?('http') && !src.start_with?('//')
              conversions << "image at line #{index + 1}"
              "#{indent}= image_tag '#{src}'#{format_image_options(attrs)}"
            else
              line
            end
          else
            line
          end
        end

        [lines.join("\n"), conversions]
      end

      def add_csrf_protection(content)
        conversions = []
        lines = content.split("\n")

        # Find head section and add CSRF meta tags
        head_index = lines.index { |line| line.strip.start_with?('head') }

        if head_index
          indent = lines[head_index][/\A */]
          csrf_tags = [
            "#{indent}  = csrf_meta_tags"
          ]

          # Insert after head tag
          lines.insert(head_index + 1, *csrf_tags)
          conversions << 'CSRF meta tags'
        end

        # Add CSRF token to forms
        lines.map!.with_index do |line, index|
          if line =~ /^(\s*)form\[.*method="(post|patch|put|delete)"/i
            # Mark that this form needs CSRF token
            conversions << "form CSRF at line #{index + 1}"
            line
          else
            line
          end
        end

        [lines.join("\n"), conversions]
      end

      def path_to_rails_helper(href)
        # Only use custom mappings if provided, no fallbacks
        return nil unless @custom_mappings

        # Remove leading slash if present for comparison
        clean_href = href.sub(%r{^/}, '')

        # Try exact match
        return @custom_mappings[href] if @custom_mappings[href]
        return @custom_mappings[clean_href] if @custom_mappings[clean_href]

        # Try pattern matching for custom mappings with wildcards
        @custom_mappings.each do |pattern, helper|
          if pattern.include?('*')
            regex_pattern = pattern.gsub('*', '.*')
            return helper if href.match?(/^#{regex_pattern}$/)
          end
        end

        nil # No mapping found
      end

      def format_link_options(attrs)
        return '' if attrs.nil? || attrs.strip.empty?

        # Parse remaining attributes
        options = []
        attrs.scan(/(\w+)="([^"]+)"/).each do |key, value|
          next if key == 'href'

          if key == 'class'
            options << "class: '#{value}'"
          elsif key == 'id'
            options << "id: '#{value}'"
          elsif key.start_with?('data-')
            data_key = key.sub('data-', '').gsub('-', '_')
            options << "data: { #{data_key}: '#{value}' }"
          else
            options << "#{key}: '#{value}'"
          end
        end

        options.empty? ? '' : ", #{options.join(", ")}"
      end

      def format_image_options(attrs)
        return '' if attrs.nil? || attrs.strip.empty?

        options = []
        attrs.scan(/(\w+)="([^"]+)"/).each do |key, value|
          next if key == 'src'

          options << if key == 'alt'
                       "alt: '#{value}'"
                     elsif key == 'class'
                       "class: '#{value}'"
                     elsif %w[width height].include?(key)
                       "#{key}: #{value}"
                     else
                       "#{key}: '#{value}'"
                     end
        end

        options.empty? ? '' : ", #{options.join(", ")}"
      end

      def show_diff(original, modified)
        puts "\n--- Original ---"
        puts original[0..500]
        puts '...' if original.length > 500
        puts "\n+++ Modified +++"
        puts modified[0..500]
        puts '...' if modified.length > 500
        puts
      end
    end
  end
end
