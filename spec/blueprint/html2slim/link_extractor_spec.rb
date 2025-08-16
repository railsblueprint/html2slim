require 'spec_helper'
require 'blueprint/html2slim/link_extractor'

RSpec.describe Blueprint::Html2Slim::LinkExtractor do
  let(:extractor) { described_class.new }
  let(:temp_file) { Tempfile.new(['test', '.slim']) }

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '#extract_links' do
    context 'with anchor links' do
      it 'extracts hardcoded HTML links' do
        content = <<~SLIM
          nav
            a[href="index.html"] Home
            a[href="/users"] Users
            a[href="about.html"] About
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = extractor.extract_links(temp_file.path)
        expect(result[:success]).to be true
        expect(result[:links].size).to eq(3)

        links = result[:links]
        expect(links[0][:href]).to eq('index.html')
        expect(links[0][:suggested_helper]).to eq('root_path')
        expect(links[1][:href]).to eq('/users')
        expect(links[1][:suggested_helper]).to eq('users_path')
        expect(links[2][:href]).to eq('about.html')
        expect(links[2][:suggested_helper]).to eq('about_path')
      end

      it 'ignores Rails helper links' do
        content = <<~SLIM
          nav
            = link_to "Home", root_path
            a[href="users_path"] Users
            a[href="<%= user_path(@user) %>"] Profile
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = extractor.extract_links(temp_file.path)
        expect(result[:success]).to be true
        expect(result[:links]).to be_empty
      end
    end

    context 'with asset links' do
      it 'extracts stylesheet and script links' do
        content = <<~SLIM
          head
            link[rel="stylesheet" href="styles.css"]
            link[rel="stylesheet" href="https://cdn.example.com/bootstrap.css"]
            script[src="app.js"]
            script[src="//cdn.example.com/jquery.js"]
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = extractor.extract_links(temp_file.path)
        expect(result[:success]).to be true
        expect(result[:links].size).to eq(2) # Only local assets

        expect(result[:links][0][:type]).to eq('stylesheet')
        expect(result[:links][0][:href]).to eq('styles.css')
        expect(result[:links][1][:type]).to eq('javascript')
        expect(result[:links][1][:href]).to eq('app.js')
      end
    end

    context 'with image sources' do
      it 'extracts local image sources' do
        content = <<~SLIM
          .gallery
            img[src="logo.png" alt="Logo"]
            img[src="/images/banner.jpg"]
            img[src="https://example.com/external.png"]
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = extractor.extract_links(temp_file.path)
        expect(result[:success]).to be true

        image_links = result[:links].select { |l| l[:type] == 'image' }
        expect(image_links.size).to eq(2) # Only local images
        expect(image_links[0][:href]).to eq('logo.png')
        expect(image_links[1][:href]).to eq('/images/banner.jpg')
      end
    end

    context 'with form actions' do
      it 'extracts form action URLs' do
        content = <<~SLIM
          form[action="/login" method="post"]
            input[type="text" name="username"]
          form[action="/users/create" method="post"]
            input[type="text" name="name"]
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = extractor.extract_links(temp_file.path)
        expect(result[:success]).to be true

        form_links = result[:links].select { |l| l[:type] == 'form' }
        expect(form_links.size).to eq(2)
        expect(form_links[0][:href]).to eq('/login')
        expect(form_links[1][:href]).to eq('/users/create')
      end
    end

    context 'with resource patterns' do
      it 'suggests appropriate Rails helpers for resource URLs' do
        content = <<~SLIM
          nav
            a[href="/users/123"] User Profile
            a[href="/posts"] All Posts
            a[href="/articles/42"] Article
            a[href="/products"] Products
        SLIM

        temp_file.write(content)
        temp_file.rewind

        result = extractor.extract_links(temp_file.path)
        links = result[:links]

        expect(links[0][:suggested_helper]).to eq('user_path(@user)')
        expect(links[1][:suggested_helper]).to eq('posts_path')
        expect(links[2][:suggested_helper]).to eq('article_path(@article)')
        expect(links[3][:suggested_helper]).to eq('products_path')
      end
    end
  end
end
