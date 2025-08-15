require 'spec_helper'

RSpec.describe 'Fixture-based conversions' do
  let(:converter) { Blueprint::Html2Slim::Converter.new }
  let(:fixtures_dir) { File.expand_path('fixtures/converter', __dir__) }

  # Group fixtures by their base name
  def fixture_pairs
    pairs = {}
    Dir.glob(File.join(fixtures_dir, '*')).each do |file|
      next if File.directory?(file)
      
      basename = File.basename(file)
      
      # Determine if this is a source or expected file
      case basename
      when /\.slim$/
        # This is an expected output file
        key = basename.sub(/\.slim$/, '')
        pairs[key] ||= {}
        pairs[key][:expected] = file
      when /\.(html|erb|html\.erb)$/
        # This is a source file
        if basename.end_with?('.html.erb')
          # erb-example.html.erb -> erb-example.html (to match erb-example.html.slim)
          key = basename.sub(/\.erb$/, '')
        else
          key = basename.sub(/\.(html|erb)$/, '')
        end
        pairs[key] ||= {}
        pairs[key][:source] = file
      end
    end
    
    # Only return complete pairs
    pairs.select { |_, files| files[:source] && files[:expected] }
  end

  describe 'converts fixtures correctly' do
    # Load fixture pairs at describe time
    fixtures_dir = File.expand_path('../fixtures', __dir__)
    pairs = {}
    
    Dir.glob(File.join(fixtures_dir, '*')).each do |file|
      next if File.directory?(file)
      
      basename = File.basename(file)
      
      case basename
      when /\.slim$/
        key = basename.sub(/\.slim$/, '')
        pairs[key] ||= {}
        pairs[key][:expected] = file
      when /\.(html|erb|html\.erb)$/
        key = basename.sub(/\.(html|erb|html\.erb)$/, '')
        key = key.sub(/\.html$/, '') if key.end_with?('.html')
        pairs[key] ||= {}
        pairs[key][:source] = file
      end
    end
    
    # Only test complete pairs
    pairs.select { |_, files| files[:source] && files[:expected] }.each do |name, files|
      it "converts #{name}" do
        source_content = File.read(files[:source])
        expected_content = File.read(files[:expected]).strip
        
        # Convert and normalize whitespace
        result = converter.convert(source_content).strip
        
        # For debugging when tests fail
        if result != expected_content
          puts "\n=== SOURCE (#{File.basename(files[:source])}) ==="
          puts source_content
          puts "\n=== EXPECTED ==="
          puts expected_content
          puts "\n=== ACTUAL ==="
          puts result
          puts "\n=== DIFF ==="
          
          expected_lines = expected_content.lines
          result_lines = result.lines
          
          max_lines = [expected_lines.length, result_lines.length].max
          max_lines.times do |i|
            exp_line = expected_lines[i]&.chomp || ''
            res_line = result_lines[i]&.chomp || ''
            
            if exp_line != res_line
              puts "Line #{i + 1}:"
              puts "  Expected: #{exp_line.inspect}"
              puts "  Actual:   #{res_line.inspect}"
            end
          end
        end
        
        expect(result).to eq(expected_content)
      end
    end
  end
  
  describe 'fixture file validation' do
    it 'has matching pairs for all fixtures' do
      all_files = Dir.glob(File.join(fixtures_dir, '*')).map { |f| File.basename(f) }
      
      sources = all_files.select { |f| f =~ /\.(html|erb|html\.erb)$/ }
      expecteds = all_files.select { |f| f =~ /\.slim$/ }
      
      sources.each do |source|
        if source.end_with?('.html.erb')
          base = source.sub(/\.erb$/, '')
        else
          base = source.sub(/\.(html|erb)$/, '')
        end
        
        matching_slim = expecteds.find { |e| e.sub(/\.slim$/, '') == base }
        expect(matching_slim).not_to be_nil, "Missing .slim file for #{source}"
      end
      
      expecteds.each do |expected|
        base = expected.sub(/\.slim$/, '')
        
        matching_source = sources.find do |s|
          if s.end_with?('.html.erb')
            s_base = s.sub(/\.erb$/, '')
          else
            s_base = s.sub(/\.(html|erb)$/, '')
          end
          s_base == base
        end
        
        expect(matching_source).not_to be_nil, "Missing source file for #{expected}"
      end
    end
    
    it 'lists all fixture pairs' do
      puts "\nFixture pairs found:"
      fixture_pairs.each do |name, files|
        source_name = File.basename(files[:source])
        expected_name = File.basename(files[:expected])
        puts "  #{name}: #{source_name} -> #{expected_name}"
      end
    end
  end
end