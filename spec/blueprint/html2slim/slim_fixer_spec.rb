require 'spec_helper'
require 'blueprint/html2slim/slim_fixer'

RSpec.describe Blueprint::Html2Slim::SlimFixer do
  let(:fixer) { described_class.new }
  let(:temp_file) { Tempfile.new(['test', '.slim']) }

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '#fix_file' do
    context 'with slash-prefix text' do
      it 'fixes text starting with slash after element' do
        content = <<~SLIM
          .pricing-card
            h2.mb-4 $29
            span.fs-6.text-muted /month
        SLIM

        expected = <<~SLIM
          .pricing-card
            h2.mb-4 $29
            span.fs-6.text-muted
              | /month
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = fixer.fix_file(temp_file.path)
        expect(result[:success]).to be true
        expect(result[:fixes]).to include(/slash text/)

        fixed_content = File.read(temp_file.path)
        expect(fixed_content.strip).to eq(expected.strip)
      end

      it 'fixes standalone text starting with slash' do
        content = <<~SLIM
          div
            /per user
            /per month
        SLIM

        expected = <<~SLIM
          div
            | /per user
            | /per month
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = fixer.fix_file(temp_file.path)
        expect(result[:success]).to be true

        fixed_content = File.read(temp_file.path)
        expect(fixed_content.strip).to eq(expected.strip)
      end

      it 'does not modify valid Slim comments' do
        content = <<~SLIM
          div
            /! HTML comment
            / Slim comment
            p Normal text
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = fixer.fix_file(temp_file.path)
        expect(result[:success]).to be true
        expect(result[:fixes]).to be_empty

        fixed_content = File.read(temp_file.path)
        expect(fixed_content.strip).to eq(content.strip)
      end
    end

    context 'with multiline text' do
      it 'fixes multiline text using pipe notation' do
        content = <<~SLIM
          p This is a long paragraph
            that continues on the next line
            and even more on this line
        SLIM

        expected = <<~SLIM
          p
            | This is a long paragraph
            | that continues on the next line
            | and even more on this line
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = fixer.fix_file(temp_file.path)
        expect(result[:success]).to be true
        expect(result[:fixes]).to include(/multiline/)

        fixed_content = File.read(temp_file.path)
        expect(fixed_content.strip).to eq(expected.strip)
      end
    end

    context 'with backup option' do
      it 'creates a backup file' do
        content = 'span /month'
        temp_file.write(content)
        temp_file.rewind

        fixer_with_backup = described_class.new(backup: true)
        result = fixer_with_backup.fix_file(temp_file.path)

        expect(result[:success]).to be true
        expect(File.exist?("#{temp_file.path}.bak")).to be true

        backup_content = File.read("#{temp_file.path}.bak")
        expect(backup_content).to eq(content)

        # Clean up backup
        File.delete("#{temp_file.path}.bak")
      end
    end

    context 'with dry_run option' do
      it 'does not modify the file' do
        original_content = 'span /month'
        temp_file.write(original_content)
        temp_file.rewind

        fixer_dry = described_class.new(dry_run: true)
        result = fixer_dry.fix_file(temp_file.path)

        expect(result[:success]).to be true

        actual_content = File.read(temp_file.path)
        expect(actual_content).to eq(original_content)
      end
    end
  end
end
