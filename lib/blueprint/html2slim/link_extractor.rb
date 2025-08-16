require_relative 'slim_manipulator'
require 'json'
require 'yaml'

module Blueprint
  module Html2Slim
    class LinkExtractor < SlimManipulator
      def extract_links(file_path)
        content = read_file(file_path)
        structure = parse_slim_structure(content)

        links = []

        structure.each do |item|
          line = item[:stripped]
          line_num = item[:line_number]

          # Extract links from anchor tags
          if line =~ /^(\s*)a\[.*href=["']([^"']+)["']/
            href = ::Regexp.last_match(2)
            # Identify hardcoded links (not Rails helpers, not variables)
            if is_hardcoded_link?(href)
              links << {
                line: line_num,
                type: 'anchor',
                href: href,
                full_line: line,
                suggested_helper: suggest_rails_helper(href)
              }
            end
          end

          # Extract links from form actions
          if line =~ /^(\s*)form\[.*action=["']([^"']+)["']/
            action = ::Regexp.last_match(2)
            if is_hardcoded_link?(action)
              links << {
                line: line_num,
                type: 'form',
                href: action,
                full_line: line,
                suggested_helper: suggest_rails_helper(action)
              }
            end
          end

          # Extract stylesheet links
          if line =~ /link\[.*href=["']([^"']+\.css[^"']*)["']/
            href = ::Regexp.last_match(1)
            if !href.start_with?('http') && !href.start_with?('//')
              links << {
                line: line_num,
                type: 'stylesheet',
                href: href,
                full_line: line,
                suggested_helper: "stylesheet_link_tag '#{File.basename(href, ".*")}'"
              }
            end
          end

          # Extract script sources
          if line =~ /script\[.*src=["']([^"']+\.js[^"']*)["']/
            src = ::Regexp.last_match(1)
            if !src.start_with?('http') && !src.start_with?('//')
              links << {
                line: line_num,
                type: 'javascript',
                href: src,
                full_line: line,
                suggested_helper: "javascript_include_tag '#{File.basename(src, ".*")}'"
              }
            end
          end

          # Extract image sources
          next unless line =~ /img\[.*src=["']([^"']+)["']/

          src = ::Regexp.last_match(1)
          next unless !src.start_with?('http') && !src.start_with?('//') && !src.include?('<%')

          links << {
            line: line_num,
            type: 'image',
            href: src,
            full_line: line,
            suggested_helper: "image_tag '#{src}'"
          }
        end

        { success: true, links: links }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      def save_links(all_links, output_path)
        format = options[:format] || 'json'

        case format
        when 'json'
          File.write(output_path, JSON.pretty_generate(all_links))
        when 'yaml'
          File.write(output_path, all_links.to_yaml)
        when 'text'
          content = []
          all_links.each do |file, links|
            content << "File: #{file}"
            links.each do |link|
              content << "  Line #{link[:line]} (#{link[:type]}): #{link[:href]}"
              content << "    Suggested: #{link[:suggested_helper]}" if link[:suggested_helper]
            end
            content << ''
          end
          File.write(output_path, content.join("\n"))
        end
      end

      def display_links(all_links)
        all_links.each do |file, links|
          puts "\n#{file}:"
          links.each do |link|
            puts "  Line #{link[:line]} (#{link[:type]}): #{link[:href]}"
            puts "    → Suggested: #{link[:suggested_helper]}" if link[:suggested_helper]
          end
        end
      end

      private

      def is_hardcoded_link?(href)
        # It's hardcoded if it's not a Rails helper or ERB expression
        return false if href.include?('_path') || href.include?('_url')
        return false if href.include?('<%') || href.include?('#{')
        return false if href.start_with?('@') || href.start_with?(':')

        # It's hardcoded if it's a static file or path
        href.match?(/\.(html|htm|php|jsp|asp)$/) ||
          href.match?(%r{^/\w+}) ||
          href == '#' ||
          href.match?(/^[a-z]+\.html$/i)
      end

      def suggest_rails_helper(href)
        # Exact matches for common pages
        common_mappings = {
          'index.html' => 'root_path',
          'home.html' => 'root_path',
          'login.html' => 'login_path',
          'signin.html' => 'login_path',
          'signup.html' => 'signup_path',
          'register.html' => 'new_user_registration_path',
          'about.html' => 'about_path',
          'contact.html' => 'contact_path',
          'privacy.html' => 'privacy_path',
          'terms.html' => 'terms_path',
          'dashboard.html' => 'dashboard_path',
          'profile.html' => 'profile_path',
          'settings.html' => 'settings_path'
        }

        # Check for exact match
        clean_href = href.sub(%r{^/}, '')
        return common_mappings[clean_href] if common_mappings[clean_href]

        # Handle resource patterns
        case href
        when %r{^/?users?/(\d+|:id)}
          'user_path(@user)'
        when %r{^/?users?$}, '/users'
          'users_path'
        when %r{^/?posts?/(\d+|:id)}
          'post_path(@post)'
        when %r{^/?posts?$}, '/posts'
          'posts_path'
        when %r{^/?articles?/(\d+|:id)}
          'article_path(@article)'
        when %r{^/?articles?$}, '/articles'
          'articles_path'
        when %r{^/?products?/(\d+|:id)}
          'product_path(@product)'
        when %r{^/?products?$}, '/products'
          'products_path'
        when /^#/
          nil # Anchor links don't need conversion
        else
          # Generic suggestion based on path
          path = href.sub(%r{^/}, '').sub(/\.\w+$/, '')
          return nil if path.empty?

          # Convert path to Rails helper format
          path_parts = path.split('/')
          if path_parts.last =~ /^\d+$/
            # Looks like a show action
            resource = path_parts[-2]
            "#{resource.singularize}_path(@#{resource.singularize})"
          else
            # Looks like an index or named route
            "#{path.gsub("/", "_").gsub("-", "_")}_path"
          end
        end
      end
    end
  end
end
