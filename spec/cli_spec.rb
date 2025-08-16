require 'spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'CLI Integration' do
  let(:cli_path) { File.expand_path('../bin/html2slim', __dir__) }

  def run_command(args, input_files = {})
    Dir.mktmpdir do |dir|
      # Create input files in temp directory
      input_paths = {}
      input_files.each do |filename, content|
        path = File.join(dir, filename)
        File.write(path, content)
        input_paths[filename] = path
      end

      # Build command with file paths
      cmd_args = args.map do |arg|
        input_paths[arg] || arg
      end.join(' ')

      # Run command
      Dir.chdir(dir) do
        stdout, _stderr, status = Open3.capture3("#{cli_path} #{cmd_args}")
        {
          stdout: stdout,
          stderr: stderr,
          status: status,
          dir: dir
        }
      end
    end
  end

  describe 'basic conversion' do
    it 'converts a simple HTML file' do
      html_content = '<div id="main"><p>Hello</p></div>'

      Dir.mktmpdir do |dir|
        input_file = File.join(dir, 'test.html')
        File.write(input_file, html_content)

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} test.html")

          expect(status).to be_success
          expect(stdout).to include('Converted: test.html -> test.html.slim')

          output_file = File.join(dir, 'test.html.slim')
          expect(File.exist?(output_file)).to be true

          content = File.read(output_file)
          expect(content).to include('#main')
          expect(content).to include('p Hello')
        end
      end
    end

    it 'converts multiple files' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'file1.html'), '<div>Content 1</div>')
        File.write(File.join(dir, 'file2.html'), '<p>Content 2</p>')

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} file1.html file2.html")

          expect(status).to be_success
          expect(stdout).to include('2 file(s) processed')
          expect(File.exist?('file1.html.slim')).to be true
          expect(File.exist?('file2.html.slim')).to be true
        end
      end
    end
  end

  describe 'output options' do
    it 'uses custom output path with -o flag' do
      Dir.mktmpdir do |dir|
        input_file = File.join(dir, 'input.html')
        File.write(input_file, '<div>Test</div>')

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} -o custom.slim input.html")

          expect(status).to be_success
          expect(stdout).to include('Converted: input.html -> custom.slim')
          expect(File.exist?('custom.slim')).to be true
        end
      end
    end

    it 'rejects -o flag with multiple files' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'file1.html'), '<div>1</div>')
        File.write(File.join(dir, 'file2.html'), '<div>2</div>')

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} -o output.slim file1.html file2.html")

          expect(status).not_to be_success
          expect(stdout).to include('Error: -o/--output can only be used with a single input file')
        end
      end
    end
  end

  describe 'backup option' do
    it 'creates backup with -b flag' do
      Dir.mktmpdir do |dir|
        input_file = File.join(dir, 'test.html')
        original_content = '<div>Original</div>'
        File.write(input_file, original_content)

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} -b test.html")

          expect(status).to be_success
          expect(stdout).to include('Backed up: test.html -> test.html.bak')
          expect(File.exist?('test.html.bak')).to be true
          expect(File.read('test.html.bak')).to eq(original_content)
          expect(File.exist?('test.html.slim')).to be true
        end
      end
    end
  end

  describe 'dry run option' do
    it 'shows what would be converted without actually converting' do
      Dir.mktmpdir do |dir|
        input_file = File.join(dir, 'test.html')
        File.write(input_file, '<div>Test</div>')

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} -n test.html")

          expect(status).to be_success
          expect(stdout).to include('Would convert: test.html -> test.html.slim')
          expect(File.exist?('test.html.slim')).to be false
        end
      end
    end

    it 'shows backup action in dry run' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'test.html'), '<div>Test</div>')

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} -n -b test.html")

          expect(status).to be_success
          expect(stdout).to include('Would backup: test.html -> test.html.bak')
          expect(File.exist?('test.html.bak')).to be false
        end
      end
    end
  end

  describe 'file naming conventions' do
    it 'converts .html to .html.slim' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'page.html'), '<div>Page</div>')

        Dir.chdir(dir) do
          _stdout, _stderr, status = Open3.capture3("#{cli_path} page.html")

          expect(status).to be_success
          expect(File.exist?('page.html.slim')).to be true
        end
      end
    end

    it 'converts .html.erb to .html.slim' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'page.html.erb'), '<div><%= @title %></div>')

        Dir.chdir(dir) do
          _stdout, _stderr, status = Open3.capture3("#{cli_path} page.html.erb")

          expect(status).to be_success
          expect(File.exist?('page.html.slim')).to be true

          content = File.read('page.html.slim')
          expect(content).to include('= @title')
        end
      end
    end

    it 'converts .erb to .slim' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'partial.erb'), '<div>Partial</div>')

        Dir.chdir(dir) do
          _stdout, _stderr, status = Open3.capture3("#{cli_path} partial.erb")

          expect(status).to be_success
          expect(File.exist?('partial.slim')).to be true
        end
      end
    end
  end

  describe 'recursive processing' do
    it 'processes directories recursively with -r flag' do
      Dir.mktmpdir do |dir|
        # Create nested directory structure
        FileUtils.mkdir_p(File.join(dir, 'views', 'users'))
        File.write(File.join(dir, 'views', 'index.html'), '<div>Index</div>')
        File.write(File.join(dir, 'views', 'users', 'show.html'), '<div>Show</div>')
        File.write(File.join(dir, 'views', 'users', 'edit.erb'), '<div>Edit</div>')

        Dir.chdir(dir) do
          _stdout, _stderr, status = Open3.capture3("#{cli_path} -r views")

          expect(status).to be_success
          expect(File.exist?('views/index.html.slim')).to be true
          expect(File.exist?('views/users/show.html.slim')).to be true
          expect(File.exist?('views/users/edit.slim')).to be true
        end
      end
    end

    it 'skips directories without -r flag' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'views'))

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} views")

          expect(status).to be_success
          expect(stdout).to include('Skipping directory: views (use -r to process recursively)')
        end
      end
    end
  end

  describe 'help and version' do
    it 'shows help with -h flag' do
      stdout, _stderr, status = Open3.capture3("#{cli_path} -h")

      expect(status).to be_success
      expect(stdout).to include('Usage: html2slim')
      expect(stdout).to include('Options:')
      expect(stdout).to include('-o, --output')
      expect(stdout).to include('-b, --backup')
    end

    it 'shows version with -v flag' do
      stdout, _stderr, status = Open3.capture3("#{cli_path} -v")

      expect(status).to be_success
      expect(stdout).to include('html2slim 1.1.0')
    end
  end

  describe 'error handling' do
    it 'handles non-existent files' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} nonexistent.html")

          expect(status).not_to be_success
          expect(stdout).to include('File not found: nonexistent.html')
          expect(stdout).to include('0 file(s) processed, 1 error(s)')
        end
      end
    end

    it 'handles no input files' do
      stdout, _stderr, status = Open3.capture3(cli_path.to_s)

      expect(status).to be_success
      expect(stdout).to include('Usage: html2slim')
    end
  end

  describe 'force overwrite' do
    it 'overwrites existing files with -f flag' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'test.html'), '<div>New</div>')
        File.write(File.join(dir, 'test.html.slim'), 'div Old')

        Dir.chdir(dir) do
          stdout, _stderr, status = Open3.capture3("#{cli_path} -f test.html")

          expect(status).to be_success
          expect(stdout).not_to include('Overwrite?')

          content = File.read('test.html.slim')
          expect(content).to include('div New')
        end
      end
    end
  end

  describe 'custom indentation' do
    it 'uses custom indent size with -i flag' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'test.html'), '<div><p>Text</p></div>')

        Dir.chdir(dir) do
          _stdout, _stderr, status = Open3.capture3("#{cli_path} -i 4 test.html")

          expect(status).to be_success

          content = File.read('test.html.slim')
          expect(content.strip).to eq("div\n    p Text")
        end
      end
    end
  end
end
