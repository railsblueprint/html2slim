require 'spec_helper'

RSpec.describe Blueprint::Html2Slim::Converter do
  let(:converter) { described_class.new }

  describe '#convert' do
    context 'with basic HTML elements' do
      it 'converts simple div' do
        html = '<div>Hello</div>'
        expected = 'div Hello'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts nested elements' do
        html = '<div><p>Hello</p></div>'
        expected = "div\n  p Hello"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts multiple siblings' do
        html = '<div>First</div><div>Second</div>'
        expected = "div First\ndiv Second"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles empty elements' do
        html = '<div></div>'
        expected = 'div'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles void elements' do
        html = '<br><hr><img src="test.jpg">'
        expected = "br\nhr\nimg[src=\"test.jpg\"]"
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with IDs and classes' do
      it 'converts div with ID' do
        html = '<div id="main">Content</div>'
        expected = '#main Content'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts div with class' do
        html = '<div class="container">Content</div>'
        expected = '.container Content'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts div with multiple classes' do
        html = '<div class="container fluid large">Content</div>'
        expected = '.container.fluid.large Content'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts div with ID and classes' do
        html = '<div id="main" class="container fluid">Content</div>'
        expected = '#main.container.fluid Content'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts non-div elements with ID and classes' do
        html = '<p id="intro" class="lead">Text</p>'
        expected = 'p#intro.lead Text'
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with attributes' do
      it 'converts elements with attributes' do
        html = '<a href="/path">Link</a>'
        expected = 'a[href="/path"] Link'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts elements with multiple attributes' do
        html = '<input type="text" name="user" value="John">'
        expected = 'input[type="text" name="user" value="John"]'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles attributes with single quotes in values' do
        html = '<div data-text="It\'s here">Content</div>'
        expected = "div[data-text=\"It's here\"] Content"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles attributes with double quotes in values' do
        html = '<div data-text=\'Say "Hello"\'>Content</div>'
        expected = 'div[data-text=\'Say "Hello"\'] Content'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'combines classes, ID, and attributes' do
        html = '<div id="main" class="container" data-role="navigation">Nav</div>'
        expected = '#main.container[data-role="navigation"] Nav'
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with ERB tags' do
      it 'converts ERB output tags' do
        html = '<div><%= @user.name %></div>'
        expected = "div\n  = @user.name"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts ERB code tags' do
        html = '<div><% if @user %><p>Hello</p><% end %></div>'
        expected = "div\n  - if @user\n    p Hello"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles ERB in attributes' do
        html = '<a href="<%= user_path(@user) %>">Profile</a>'
        expected = 'a[href="<%= user_path(@user) %>"] Profile'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'converts mixed HTML and ERB' do
        html = '<div><%= @title %><p>Static content</p><% @items.each do |item| %><li><%= item %></li><% end %></div>'
        expected = "div\n  = @title\n  p Static content\n  - @items.each do |item|\n    li\n      = item"
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with text content' do
      it 'handles inline text' do
        html = '<p>This is a paragraph with text.</p>'
        expected = 'p This is a paragraph with text.'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles multiline text' do
        html = "<div>\n  Line 1\n  Line 2\n</div>"
        expected = "div\n  | Line 1\n  | Line 2"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles mixed text and elements' do
        html = '<div>Text before <span>inline</span> text after</div>'
        expected = "div\n  | Text before\n  span inline\n  | text after"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'preserves whitespace in pre tags' do
        html = '<pre>  Indented\n    More indented</pre>'
        expected = 'pre Indented\\n    More indented'
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with comments' do
      it 'converts HTML comments' do
        html = '<!-- This is a comment -->'
        expected = '/! This is a comment'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles comments with elements' do
        html = '<div><!-- Comment --><p>Content</p></div>'
        expected = "div\n  /! Comment\n  p Content"
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with complex nested structures' do
      it 'converts complex nested HTML' do
        html = <<-HTML
          <div id="wrapper" class="container">
            <header>
              <h1>Title</h1>
              <nav>
                <ul>
                  <li><a href="/">Home</a></li>
                  <li><a href="/about">About</a></li>
                </ul>
              </nav>
            </header>
            <main>
              <article class="post">
                <h2>Post Title</h2>
                <p>Content here</p>
              </article>
            </main>
          </div>
        HTML

        result = converter.convert(html)
        expect(result.strip).to include('#wrapper.container')
        expect(result.strip).to include('header')
        expect(result.strip).to include('h1 Title')
        expect(result.strip).to include('nav')
        expect(result.strip).to include('ul')
        expect(result.strip).to include('li')
        expect(result.strip).to include('a[href="/"] Home')
        expect(result.strip).to include('a[href="/about"] About')
        expect(result.strip).to include('main')
        expect(result.strip).to include('article.post')
        expect(result.strip).to include('h2 Post Title')
        expect(result.strip).to include('p Content here')
      end
    end

    context 'with custom indentation' do
      let(:converter) { described_class.new(indent_size: 4) }

      it 'uses custom indent size' do
        html = '<div><p>Text</p></div>'
        expected = "div\n    p Text"
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with form elements' do
      it 'converts form with inputs' do
        html = <<-HTML
          <form action="/submit" method="post">
            <input type="text" name="username" placeholder="Username">
            <input type="password" name="password">
            <button type="submit">Login</button>
          </form>
        HTML

        result = converter.convert(html)
        expect(result.strip).to include('form[action="/submit" method="post"]')
        expect(result.strip).to include('input[type="text" name="username" placeholder="Username"]')
        expect(result.strip).to include('input[type="password" name="password"]')
        expect(result.strip).to include('button[type="submit"] Login')
      end

      it 'converts select with options' do
        html = <<-HTML
          <select name="country">
            <option value="us">United States</option>
            <option value="uk" selected>United Kingdom</option>
          </select>
        HTML

        result = converter.convert(html)
        expect(result.strip).to include('select[name="country"]')
        expect(result.strip).to include('option[value="us"] United States')
        expect(result.strip).to include('option[value="uk" selected="selected"] United Kingdom')
      end

      it 'converts textarea' do
        html = '<textarea name="message" rows="5" cols="30">Default text</textarea>'
        expected = 'textarea[name="message" rows="5" cols="30"] Default text'
        expect(converter.convert(html).strip).to eq(expected)
      end
    end

    context 'with tables' do
      it 'converts simple table' do
        html = <<-HTML
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Age</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>John</td>
                <td>30</td>
              </tr>
            </tbody>
          </table>
        HTML

        result = converter.convert(html)
        expect(result.strip).to include('table')
        expect(result.strip).to include('thead')
        expect(result.strip).to include('tbody')
        expect(result.strip).to include('tr')
        expect(result.strip).to include('th Name')
        expect(result.strip).to include('th Age')
        expect(result.strip).to include('td John')
        expect(result.strip).to include('td 30')
      end
    end

    context 'with HTML5 semantic elements' do
      it 'converts HTML5 elements' do
        html = <<-HTML
          <article>
            <header>
              <h1>Article Title</h1>
              <time datetime="2024-01-01">January 1, 2024</time>
            </header>
            <section>
              <p>Content</p>
            </section>
            <footer>
              <p>Footer info</p>
            </footer>
          </article>
        HTML

        result = converter.convert(html)
        expect(result.strip).to include('article')
        expect(result.strip).to include('header')
        expect(result.strip).to include('section')
        expect(result.strip).to include('footer')
        expect(result.strip).to include('time[datetime="2024-01-01"] January 1, 2024')
      end

      it 'converts figure with figcaption' do
        html = <<-HTML
          <figure>
            <img src="image.jpg" alt="Description">
            <figcaption>Image caption</figcaption>
          </figure>
        HTML

        result = converter.convert(html)
        expect(result.strip).to include('figure')
        expect(result.strip).to include('img[src="image.jpg" alt="Description"]')
        expect(result.strip).to include('figcaption Image caption')
      end
    end
  end
end
