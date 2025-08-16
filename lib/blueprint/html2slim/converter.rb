require 'nokogiri'
require 'erubi'
require 'strscan'

module Blueprint
  module Html2Slim
    class Converter
      VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze
      INLINE_ELEMENTS = %w[a abbr b bdo br cite code dfn em i kbd mark q s samp small span strong sub sup time u
                           var].freeze

      def initialize(options = {})
        @options = options
        @indent_size = options[:indent_size] || 2
        @erb_pattern = /<%(-|=)?(.+?)(-)?%>/m
      end

      def convert(html_content)
        lines = []

        # Handle DOCTYPE declaration
        if html_content =~ /<!DOCTYPE\s+(.+?)>/i
          doctype_content = ::Regexp.last_match(1)
          lines << if doctype_content =~ /strict/i
                     'doctype strict'
                   elsif doctype_content =~ /transitional/i
                     'doctype transitional'
                   elsif doctype_content =~ /frameset/i
                     'doctype frameset'
                   elsif doctype_content =~ /html$/i
                     'doctype html'
                   else
                     'doctype'
                   end
          # Remove DOCTYPE from content for further processing
          html_content = html_content.sub(/<!DOCTYPE\s+.+?>/i, '')
        end

        html_content = preprocess_erb(html_content)
        # Use HTML.parse for full documents, DocumentFragment for fragments
        if html_content =~ /<html/i
          doc = Nokogiri::HTML.parse(html_content)
          # Process the html element if it exists
          if html_element = doc.at('html')
            node_lines = process_node(html_element, 0)
            lines.concat(node_lines) unless node_lines.empty?
          else
            doc.root.children.each do |node|
              node_lines = process_node(node, 0)
              lines.concat(node_lines) unless node_lines.empty?
            end
          end
        else
          doc = Nokogiri::HTML::DocumentFragment.parse(html_content)
          doc.children.each do |node|
            node_lines = process_node(node, 0)
            lines.concat(node_lines) unless node_lines.empty?
          end
        end
        result = lines.join("\n")
        # Ensure the result ends with a newline
        result += "\n" unless result.end_with?("\n")
        result
      end

      private

      def preprocess_erb(content)
        # Convert ERB blocks to span elements to preserve hierarchy
        # This approach is inspired by the original html2slim gem

        # Keep ERB tags in attributes unchanged by temporarily replacing them
        erb_in_attrs = []
        content = content.gsub(/(<[^>]*)(<%=?.+?%>)([^>]*>)/) do
          before = ::Regexp.last_match(1)
          erb = ::Regexp.last_match(2)
          after = ::Regexp.last_match(3)
          placeholder = "ERB_IN_ATTR_#{erb_in_attrs.length}"
          erb_in_attrs << erb
          "#{before}#{placeholder}#{after}"
        end

        # Handle multi-line ERB blocks first (with m flag for multiline)
        content = content.gsub(/<%\s*\n(.*?)\n\s*-?%>/m) do
          code_block = ::Regexp.last_match(1).strip
          # Mark as multiline block for special handling
          "<!--ERB_MULTILINE_CODE:#{code_block.gsub("-->", "__ARROW__")}-->"
        end

        # Handle multiline ERB output blocks (e.g., <%= form_with(...) spanning multiple lines %>)
        content = content.gsub(/<%=\s*\n(.*?)\n\s*-?%>/m) do
          code_block = ::Regexp.last_match(1).strip
          # Check if it ends with do block
          if code_block =~ /\bdo\s*(\|[^|]*\|)?\s*$/
            # Convert to single line for block processing
            single_line = code_block.gsub(/\s+/, ' ')
            "<%= #{single_line} %>" # Keep for block processing
          else
            # Mark as multiline output for special handling
            "<!--ERB_MULTILINE_OUTPUT:#{code_block.gsub("-->", "__ARROW__")}-->"
          end
        end

        # Convert simple ERB output tags that don't create blocks
        # This prevents them from being caught by the block regex
        content = content.gsub(/<%=\s*([^%]+?)\s*%>/) do
          code = ::Regexp.last_match(1).strip
          # Skip if it's a do block
          if code =~ /\bdo\s*(\|[^|]*\|)?\s*$/
            "<%= #{code} %>" # Keep original, will be processed later
          else
            %(<!--ERB_OUTPUT:#{code}-->)
          end
        end

        # Convert ERB blocks that create structure (do...end, if...end, etc.)
        # to span elements so their content becomes proper children
        content = content.gsub(/<%(-|=)?\s*((\s*(case|if|for|unless|until|while) .+?)|.+?do\s*(\|[^|]*\|)?\s*)-?%>/m) do
          type = ::Regexp.last_match(1)
          code = ::Regexp.last_match(2).strip
          # Preserve whether it was = or - in the code attribute
          prefix = type == '=' ? '=' : ''
          %(<span erb-code="#{prefix}#{code.gsub('"', "&quot;")}">)
        end

        # Handle else
        content = content.gsub(/<%-?\s*else\s*-?%>/, %(</span><span erb-code="else">))

        # Handle elsif
        content = content.gsub(/<%-?\s*(elsif .+?)\s*-?%>/) do
          code = ::Regexp.last_match(1).strip
          %(</span><span erb-code="#{code.gsub('"', "&quot;")}">)
        end

        # Handle when
        content = content.gsub(/<%-?\s*(when .+?)\s*-?%>/) do
          code = ::Regexp.last_match(1).strip
          %(</span><span erb-code="#{code.gsub('"', "&quot;")}">)
        end

        # Handle end statements - close the span
        content = content.gsub(/<%\s*(end|}|end\s+-)\s*%>/, %(</span>))

        # Convert any remaining ERB code tags to comments
        content = content.gsub(/<%-?\s*(.+?)\s*%>/) do
          code = ::Regexp.last_match(1).strip
          %(<!--ERB_CODE:#{code}-->)
        end

        # Restore ERB tags in attributes
        erb_in_attrs.each_with_index do |erb, i|
          content = content.gsub("ERB_IN_ATTR_#{i}", erb)
        end

        content
      end

      def process_node(node, depth)
        case node
        when Nokogiri::XML::Element
          process_element(node, depth)
        when Nokogiri::XML::Text
          process_text(node, depth)
        when Nokogiri::XML::Comment
          process_comment(node, depth)
        else
          []
        end
      end

      def process_element(node, depth)
        lines = []
        indent = ' ' * (depth * @indent_size)

        # Check if this is an ERB span element
        if node.name == 'span' && node['erb-code']
          erb_code = node['erb-code'].gsub('&quot;', '"')

          # Determine if it's output (=) or code (-)
          lines << if erb_code =~ /^(if|unless|case|for|while|elsif|else|when)\b/
                     "#{indent}- #{erb_code}"
                   elsif erb_code.start_with?('=')
                     # It was originally <%= ... %>, use = prefix
                     "#{indent}= #{erb_code[1..-1].strip}"
                   else
                     # It was originally <% ... %>, use - prefix
                     "#{indent}- #{erb_code}"
                   end

          # Process children with increased depth
          node.children.each do |child|
            child_lines = process_node(child, depth + 1)
            lines.concat(child_lines) unless child_lines.empty?
          end

          return lines
        end

        tag_line = build_tag_line(node, depth)

        if VOID_ELEMENTS.include?(node.name.downcase)
          lines << "#{indent}#{tag_line}"
        elsif node.children.empty?
          lines << "#{indent}#{tag_line}"
        elsif single_text_child?(node)
          text = node.children.first.text
          if text.strip.empty?
            lines << "#{indent}#{tag_line}"
          elsif node.name.downcase == 'pre'
            # Preserve whitespace in pre tags but still strip leading/trailing
            text = text.strip.gsub(/\n\s*/, '\n ')
            lines << "#{indent}#{tag_line} #{text}"
          elsif text.include?("\n") && text.strip.lines.count > 1
            # Multiline text - use pipe notation
            lines << "#{indent}#{tag_line}"
            text.strip.lines.each do |line|
              lines << "#{" " * ((depth + 1) * @indent_size)}| #{line.strip}" unless line.strip.empty?
            end
          else
            text = process_inline_text(text.strip)
            if text.empty?
              lines << "#{indent}#{tag_line}"
            elsif text.start_with?('/')
              # Text starting with / needs pipe notation to avoid being treated as comment
              lines << "#{indent}#{tag_line}"
              lines << "#{" " * ((depth + 1) * @indent_size)}| #{text}"
            else
              lines << "#{indent}#{tag_line} #{text}"
            end
          end
        else
          lines << "#{indent}#{tag_line}"
          node.children.each do |child|
            child_lines = process_node(child, depth + 1)
            lines.concat(child_lines) unless child_lines.empty?
          end
        end

        lines
      end

      def build_tag_line(node, _depth)
        tag = node.name
        id = node['id']
        # Strip and split classes, filtering out empty strings
        classes = node['class']&.strip&.split(/\s+/)&.reject(&:empty?) || []
        attributes = collect_attributes(node)

        # Treat empty id as no id
        id = nil if id && id.strip.empty?

        line = if tag.downcase == 'div' && (id || !classes.empty?)
                 ''
               else
                 tag
               end

        line += "##{id}" if id

        classes.each do |cls|
          line += ".#{cls}"
        end

        unless attributes.empty?
          line = 'div' if line.empty?
          line += build_attribute_string(attributes)
        end

        line = tag if line.empty?
        line
      end

      def collect_attributes(node)
        attributes = {}
        node.attributes.each do |name, attr|
          next if %w[id class].include?(name)

          attributes[name] = attr.value
        end
        attributes
      end

      def build_attribute_string(attributes)
        return '' if attributes.empty?

        attr_parts = attributes.map do |key, value|
          if value.nil? || value == ''
            key
          elsif value.include?('"')
            "#{key}='#{value}'"
          else
            "#{key}=\"#{value}\""
          end
        end

        "[#{attr_parts.join(" ")}]"
      end

      def process_text(node, depth)
        text = node.text
        return [] if text.strip.empty? && !text.include?("\n")

        indent = ' ' * (depth * @indent_size)
        processed_text = process_inline_text(text.strip)
        return [] if processed_text.empty?

        if processed_text.include?("\n")
          processed_text.split("\n").map { |line| "#{indent}| #{line}" }
        else
          ["#{indent}| #{processed_text}"]
        end
      end

      def process_comment(node, depth)
        comment_text = node.text.strip

        # Extract indentation level if present
        extra_indent = 0
        if comment_text =~ /:INDENT:(\d+)$/
          extra_indent = ::Regexp.last_match(1).to_i
          comment_text = comment_text.sub(/:INDENT:\d+$/, '')
        end

        total_depth = depth + extra_indent
        indent = ' ' * (total_depth * @indent_size)

        if comment_text.start_with?('ERB_MULTILINE_CODE:')
          erb_content = comment_text.sub('ERB_MULTILINE_CODE:', '').gsub('__ARROW__', '-->')
          # Use ruby: block for multiline code
          lines = ["#{indent}ruby:"]
          erb_content.lines.each do |line|
            lines << "#{indent}  #{line.rstrip}"
          end
          lines
        elsif comment_text.start_with?('ERB_MULTILINE_OUTPUT:')
          erb_content = comment_text.sub('ERB_MULTILINE_OUTPUT:', '').gsub('__ARROW__', '-->')
          # For multiline output, use line continuation
          lines = erb_content.lines.map(&:rstrip)
          if lines.length == 1
            ["#{indent}= #{lines[0]}"]
          else
            result = ["#{indent}= #{lines[0]} \\"]
            lines[1..-2].each do |line|
              result << "#{indent}    #{line} \\"
            end
            result << "#{indent}    #{lines[-1]}" if lines.length > 1
            result
          end
        elsif comment_text.start_with?('ERB_OUTPUT_BLOCK:')
          erb_content = comment_text.sub('ERB_OUTPUT_BLOCK:', '')
          ["#{indent}= #{erb_content}"]
        elsif comment_text.start_with?('ERB_OUTPUT:')
          erb_content = comment_text.sub('ERB_OUTPUT:', '')
          ["#{indent}= #{erb_content}"]
        elsif comment_text.start_with?('ERB_CODE_BLOCK:')
          erb_content = comment_text.sub('ERB_CODE_BLOCK:', '')
          ["#{indent}- #{erb_content}"]
        elsif comment_text.start_with?('ERB_CODE:')
          erb_content = comment_text.sub('ERB_CODE:', '')
          ["#{indent}- #{erb_content}"]
        elsif comment_text == 'ERB_END'
          # Don't output 'end' statements in Slim
          []
        else
          ["#{indent}/! #{comment_text}"]
        end
      end

      def process_inline_text(text)
        text.gsub(/\s+/, ' ').strip
      end

      def single_text_child?(node)
        node.children.size == 1 && node.children.first.text?
      end
    end
  end
end
