require 'spec_helper'
require 'blueprint/html2slim/slim_validator'

RSpec.describe Blueprint::Html2Slim::SlimValidator do
  let(:validator) { described_class.new }
  let(:temp_file) { Tempfile.new(['test', '.slim']) }

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '#validate_file' do
    context 'with valid Slim syntax' do
      it 'validates correct Slim file' do
        content = <<~SLIM
          doctype html
          html
            head
              title Test Page
            body
              h1 Welcome
              p This is valid Slim
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = validator.validate_file(temp_file.path)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end
    end

    context 'with invalid syntax' do
      it 'detects text starting with slash' do
        content = <<~SLIM
          div
            span /month
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = validator.validate_file(temp_file.path)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/Forward slash will be interpreted as comment/)
      end

      it 'detects invalid indentation jumps' do
        content = <<~SLIM
          div
                p Too much indentation
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = validator.validate_file(temp_file.path)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/Invalid indentation jump/)
      end

      it 'detects unclosed brackets' do
        content = <<~SLIM
          div[class="test"
            p Content
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = validator.validate_file(temp_file.path)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/Unclosed attribute bracket/)
      end

      it 'detects empty Ruby code markers' do
        content = <<~SLIM
          div
            =
            p Content
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = validator.validate_file(temp_file.path)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/Ruby code marker without code/)
      end
    end

    context 'with warnings' do
      it 'warns about long lines' do
        content = "p #{'x' * 150}"

        temp_file.write(content)
        temp_file.rewind

        result = validator.validate_file(temp_file.path)
        expect(result[:valid]).to be true
        expect(result[:warnings]).to include(/Line exceeds 120 characters/)
      end

      it 'warns about potential slash issues' do
        content = <<~SLIM
          p Price is $29 /month for the basic plan
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = validator.validate_file(temp_file.path)
        expect(result[:valid]).to be true
        expect(result[:warnings]).to include(%r{Text containing '/'.* might need pipe notation})
      end
    end

    context 'with Rails checks' do
      let(:rails_validator) { described_class.new(check_rails: true) }

      it 'warns about static asset links' do
        content = <<~SLIM
          head
            link[rel="stylesheet" href="styles.css"]
            script[src="app.js"]
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = rails_validator.validate_file(temp_file.path)
        expect(result[:warnings]).to include(/Consider using stylesheet_link_tag/)
        expect(result[:warnings]).to include(/Consider using javascript_include_tag/)
      end

      it 'warns about hardcoded URLs' do
        content = <<~SLIM
          nav
            a[href="/users"] Users
            a[href="/posts/123"] View Post
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = rails_validator.validate_file(temp_file.path)
        expect(result[:warnings]).to include(/Consider using Rails path helpers/)
      end

      it 'warns about forms without Rails helpers' do
        content = <<~SLIM
          form[action="/submit" method="post"]
            input[type="text" name="user[name]"]
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = rails_validator.validate_file(temp_file.path)
        expect(result[:warnings]).to include(/Consider using Rails form helpers/)
        expect(result[:warnings]).to include(/Ensure CSRF token is included/)
      end
    end

    context 'with strict mode' do
      let(:strict_validator) { described_class.new(strict: true) }

      it 'warns about inline styles' do
        content = <<~SLIM
          div[style="color: red;"] Styled text
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = strict_validator.validate_file(temp_file.path)
        expect(result[:warnings]).to include(/Inline styles detected/)
      end
    end
  end
end
