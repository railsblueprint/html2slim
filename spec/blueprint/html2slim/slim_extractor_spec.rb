require 'spec_helper'
require 'blueprint/html2slim/slim_extractor'

RSpec.describe Blueprint::Html2Slim::SlimExtractor do
  let(:extractor) { described_class.new }
  let(:temp_file) { Tempfile.new(['test', '.slim']) }
  let(:output_file) { Tempfile.new(['output', '.slim']) }

  after do
    temp_file.close
    temp_file.unlink
    output_file.close
    output_file.unlink
  end

  describe '#extract_file' do
    context 'with outline extraction' do
      it 'extracts outline up to specified depth' do
        content = <<~SLIM
          doctype html
          html
            head
              title Test Page
              meta[charset="utf-8"]
            body
              nav
                ul
                  li
                    a[href="/"] Home
              main
                article
                  h1 Title
                  p Content here
                  section
                    h2 Subtitle
                    p More content
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_outline = described_class.new(outline: 2, output: output_file.path)
        result = extractor_with_outline.extract_file(temp_file.path)

        expect(result[:success]).to be true

        extracted = File.read(output_file.path)
        expect(extracted).to include('doctype html')
        expect(extracted).to include('html')
        expect(extracted).to include('  head')
        expect(extracted).to include('  body')

        # Should not include deeper nested content
        expect(extracted).not_to include('title Test Page')
        expect(extracted).not_to include('nav')
        expect(extracted).not_to include('main')
        expect(extracted).not_to include('Home')
      end

      it 'extracts three levels deep' do
        content = <<~SLIM
          html
            body
              div
                span Deep content
                p More deep content
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_outline = described_class.new(outline: 3, output: output_file.path)
        extractor_with_outline.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('html')
        expect(extracted).to include('  body')
        expect(extracted).to include('    div')
        expect(extracted).not_to include('span Deep content')
      end
    end

    context 'with CSS selector extraction' do
      it 'extracts element by ID' do
        content = <<~SLIM
          body
            header
              h1 Header
            main#content
              p Main content
              section
                p Nested content
            footer
              p Footer
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_selector = described_class.new(selector: '#content', output: output_file.path)
        extractor_with_selector.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('main#content')
        expect(extracted).to include('p Main content')
        expect(extracted).to include('section')
        expect(extracted).to include('p Nested content')
        expect(extracted).not_to include('header')
        expect(extracted).not_to include('footer')
      end

      it 'extracts elements by class' do
        content = <<~SLIM
          div
            section.intro
              h2 Introduction
              p Intro text
            section.main
              h2 Main Section
              p Main text
            section.outro
              h2 Conclusion
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_selector = described_class.new(selector: '.main', output: output_file.path)
        extractor_with_selector.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('section.main')
        expect(extracted).to include('h2 Main Section')
        expect(extracted).to include('p Main text')
        expect(extracted).not_to include('Introduction')
        expect(extracted).not_to include('Conclusion')
      end

      it 'extracts element with specific class' do
        content = <<~SLIM
          body
            div.container
              p Container 1
            article.container
              p Article container
            div.wrapper
              p Wrapper content
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_selector = described_class.new(selector: 'article.container', output: output_file.path)
        extractor_with_selector.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('article.container')
        expect(extracted).to include('p Article container')
        expect(extracted).not_to include('Container 1')
        expect(extracted).not_to include('Wrapper content')
      end

      it 'extracts element with ID and class' do
        content = <<~SLIM
          main
            section#intro.highlight
              h2 Highlighted intro
              p Content
            section#main
              h2 Main section
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_selector = described_class.new(selector: '#intro.highlight', output: output_file.path)
        extractor_with_selector.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('section#intro.highlight')
        expect(extracted).to include('h2 Highlighted intro')
        expect(extracted).not_to include('Main section')
      end

      it 'extracts by element name' do
        content = <<~SLIM
          body
            header
              h1 Title
            article
              h2 Article Title
              p Article content
            aside
              p Sidebar
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_selector = described_class.new(selector: 'article', output: output_file.path)
        extractor_with_selector.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('article')
        expect(extracted).to include('h2 Article Title')
        expect(extracted).to include('p Article content')
        expect(extracted).not_to include('header')
        expect(extracted).not_to include('Sidebar')
      end
    end

    context 'with original keep/remove logic' do
      it 'removes specified sections' do
        content = <<~SLIM
          doctype html
          html
            head
              title Test
            body
              nav
                a[href="/"] Home
              main
                p Content
              footer
                p Footer
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_remove = described_class.new(remove: %w[head nav footer], output: output_file.path)
        extractor_with_remove.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('main')
        expect(extracted).not_to include('head')
        expect(extracted).not_to include('nav')
        expect(extracted).not_to include('footer')
      end

      it 'keeps only specified sections' do
        content = <<~SLIM
          body
            header
              h1 Header
            main
              p Main content
            footer
              p Footer
        SLIM

        temp_file.write(content)
        temp_file.rewind

        extractor_with_keep = described_class.new(keep: %w[main], output: output_file.path)
        extractor_with_keep.extract_file(temp_file.path)

        extracted = File.read(output_file.path)
        expect(extracted).to include('main')
        expect(extracted).to include('p Main content')
        expect(extracted).not_to include('header')
        expect(extracted).not_to include('footer')
      end
    end
  end
end
