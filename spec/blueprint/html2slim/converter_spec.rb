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

      it 'handles multiline ERB code blocks' do
        html = <<-HTML
          <div>
            <%
              user = User.find(params[:id])
              posts = user.posts.published
              comments = user.comments.recent
            %>
            <h1><%= user.name %></h1>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('ruby:')
        expect(result).to include('user = User.find(params[:id])')
        expect(result).to include('posts = user.posts.published')
        expect(result).to include('comments = user.comments.recent')
        expect(result).to include('h1')
        expect(result).to include('= user.name')
      end

      it 'handles multiline ERB with if statements' do
        html = <<-HTML
          <div>
            <%
              if user.admin?
                role = "Administrator"
              else
                role = "User"
              end
            %>
            <span><%= role %></span>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('ruby:')
        expect(result).to include('if user.admin?')
        expect(result).to include('role = "Administrator"')
        expect(result).to include('else')
        expect(result).to include('role = "User"')
        expect(result).to include('end')
        expect(result).to include('span')
        expect(result).to include('= role')
      end

      it 'handles multiline ERB output blocks' do
        html = <<-HTML
          <div>
            <%=
              link_to "Profile",
                      user_path(@user),
                      class: "btn btn-primary",
                      data: { confirm: "Are you sure?" }
            %>
          </div>
        HTML
        result = converter.convert(html)
        # The multiline output should be preserved as a single output statement
        expect(result).to include('= link_to "Profile",')
      end

      it 'handles multiline hash definitions in ERB' do
        html = <<-HTML
          <div>
            <%
              options = {
                class: "form-control",
                placeholder: "Enter your name",
                required: true,
                data: {
                  validate: "presence",
                  message: "Name is required"
                }
              }
            %>
            <%= text_field_tag :name, nil, options %>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('ruby:')
        expect(result).to include('options = {')
        expect(result).to include('class: "form-control",')
        expect(result).to include('placeholder: "Enter your name",')
        expect(result).to include('required: true,')
        expect(result).to include('data: {')
        expect(result).to include('validate: "presence",')
        expect(result).to include('message: "Name is required"')
        expect(result).to include('= text_field_tag :name, nil, options')
      end

      it 'handles multiline array definitions in ERB' do
        html = <<-HTML
          <div>
            <%
              items = [
                { name: "Apple", price: 1.99 },
                { name: "Banana", price: 0.99 },
                { name: "Orange", price: 2.49 },
                { name: "Grape", price: 3.99 }
              ]
            %>
            <% items.each do |item| %>
              <p><%= item[:name] %>: $<%= item[:price] %></p>
            <% end %>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('ruby:')
        expect(result).to include('items = [')
        expect(result).to include('{ name: "Apple", price: 1.99 },')
        expect(result).to include('{ name: "Banana", price: 0.99 },')
        expect(result).to include('- items.each do |item|')
        expect(result).to include('= item[:name]')
        expect(result).to include('= item[:price]')
      end

      it 'handles complex multiline method calls in ERB output' do
        html = <<-HTML
          <div class="form-wrapper">
            <%= form_with(
                  model: @user,
                  url: user_path(@user),
                  method: :patch,
                  local: true,
                  html: {
                    class: "user-form",
                    data: {
                      remote: false,
                      confirm: "Save changes?"
                    }
                  }
                ) do |f| %>
              <%= f.text_field :name %>
              <%= f.submit "Save" %>
            <% end %>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('.form-wrapper')
        expect(result).to include('= form_with(')
        expect(result).to include('= f.text_field :name')
        expect(result).to include('= f.submit "Save"')
      end

      it 'handles multiline string concatenation in ERB' do
        html = <<-HTML
          <div>
            <%
              message = "Welcome to our site! " +
                        "We're glad you're here. " +
                        "Please take a moment to " +
                        "complete your profile."
            %>
            <p><%= message %></p>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('ruby:')
        expect(result).to include('message = "Welcome to our site! " +')
        expect(result).to include('"We\'re glad you\'re here. " +')
        expect(result).to include('"Please take a moment to " +')
        expect(result).to include('"complete your profile."')
        expect(result).to include('= message')
      end

      it 'handles inline array with each method' do
        html = <<-HTML
          <div>
            <%
              [
                { name: "Apple", price: 1.99 },
                { name: "Banana", price: 0.99 }
              ].each do |item| %>
              <p><%= item[:name] %>: $<%= item[:price] %></p>
            <% end %>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('- [')
        expect(result).to include('{ name: "Apple", price: 1.99 },')
        expect(result).to include('{ name: "Banana", price: 0.99 }')
        expect(result).to include('].each do |item|')
        expect(result).to include('= item[:name]')
        expect(result).to include('= item[:price]')
      end

      it 'handles nested ERB control structures' do
        html = <<-HTML
          <div>
            <% @users.each do |user| %>
              <div class="user">
                <% if user.active? %>
                  <span class="status">Active</span>
                  <% user.posts.each do |post| %>
                    <article>
                      <h3><%= post.title %></h3>
                      <p><%= post.body %></p>
                    </article>
                  <% end %>
                <% else %>
                  <span class="status">Inactive</span>
                <% end %>
              </div>
            <% end %>
          </div>
        HTML
        result = converter.convert(html)
        expect(result).to include('- @users.each do |user|')
        expect(result).to include('.user')
        expect(result).to include('- if user.active?')
        expect(result).to include('span.status Active')
        expect(result).to include('- user.posts.each do |post|')
        expect(result).to include('article')
        expect(result).to include('h3')
        expect(result).to include('= post.title')
        expect(result).to include('= post.body')
        expect(result).to include('- else')
        expect(result).to include('span.status Inactive')
      end

      it 'handles ERB blocks with complex indentation' do
        html = <<-HTML
          <% if @user %>
            <div class="user-profile">
              <%
                full_name = [@user.first_name, @user.last_name].join(' ')
                age = Date.today.year - @user.birth_date.year
              %>
              <h2><%= full_name %></h2>
              <p>Age: <%= age %></p>
            </div>
          <% end %>
        HTML
        result = converter.convert(html)
        expect(result).to include('- if @user')
        expect(result).to include('.user-profile')
        expect(result).to include('ruby:')
        expect(result).to include("full_name = [@user.first_name, @user.last_name].join(' ')")
        expect(result).to include('age = Date.today.year - @user.birth_date.year')
        expect(result).to include('h2')
        expect(result).to include('= full_name')
        expect(result).to include("p\n      | Age:")
        expect(result).to include('= age')
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

    context 'with Unicode characters' do
      it 'handles CJK characters' do
        html = '<div>Hello 世界</div><p>日本語 テスト</p><span>中文测试</span>'
        result = converter.convert(html)
        expect(result).to include('div Hello 世界')
        expect(result).to include('p 日本語 テスト')
        expect(result).to include('span 中文测试')
      end

      it 'handles emoji characters' do
        html = '<div class="emoji">🎉 Party 🚀 Rocket ❤️ Love</div>'
        expected = '.emoji 🎉 Party 🚀 Rocket ❤️ Love'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles European accented characters' do
        html = '<p>Café €100 ñoño àèìòù äëïöü</p>'
        expected = 'p Café €100 ñoño àèìòù äëïöü'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles Cyrillic characters' do
        html = '<span>Здравствуй мир</span>'
        expected = 'span Здравствуй мир'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles Arabic and Hebrew characters' do
        html = '<h1>العربية اختبار</h1><h2>עברית בדיקה</h2>'
        result = converter.convert(html)
        expect(result).to include('h1 العربية اختبار')
        expect(result).to include('h2 עברית בדיקה')
      end

      it 'handles mixed Unicode in attributes' do
        html = '<div title="日本語 título" data-emoji="🎉">Content</div>'
        expected = 'div[title="日本語 título" data-emoji="🎉"] Content'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles Unicode in class names' do
        html = '<div class="класс 类名">Test</div>'
        expected = '.класс.类名 Test'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles Unicode with slash prefix' do
        html = '<p>/日本語 price</p><span>/€100</span>'
        result = converter.convert(html)
        expect(result).to include("p\n  | /日本語 price")
        expect(result).to include("span\n  | /€100")
      end
    end

    context 'with text content' do
      it 'handles inline text' do
        html = '<p>This is a paragraph with text.</p>'
        expected = 'p This is a paragraph with text.'
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles text starting with slash inside span elements' do
        html = '<h2 class="mb-4">$29<span class="fs-6 text-muted">/month</span></h2>'
        expected = "h2.mb-4\n  | $29\n  span.fs-6.text-muted\n    | /month"
        expect(converter.convert(html).strip).to eq(expected)
      end

      it 'handles Bootstrap pricing card with text starting with slash' do
        html = <<-HTML
          <div class="row g-4 justify-content-center">
              <div class="col-lg-4">
                  <div class="pricing-card">
                      <h4 class="mb-4">Starter</h4>
                      <h2 class="mb-4">$29<span class="fs-6 text-muted">/month</span></h2>
                      <ul class="list-unstyled mb-4">
                          <li class="mb-2"><i class="fas fa-check text-success me-2"></i> 100K API calls</li>
                          <li class="mb-2"><i class="fas fa-check text-success me-2"></i> Basic models</li>
                          <li class="mb-2"><i class="fas fa-check text-success me-2"></i> Email support</li>
                          <li class="mb-2"><i class="fas fa-check text-success me-2"></i> Dashboard access</li>
                      </ul>
                      <a href="pricing.html" class="btn btn-outline-primary w-100">Learn More</a>
                  </div>
              </div>
          </div>
        HTML

        result = converter.convert(html)
        # Check that the /month text is properly preserved with pipe notation
        expect(result).to include("span.fs-6.text-muted\n          | /month")
        # Check other key elements are present
        expect(result).to include('.row.g-4.justify-content-center')
        expect(result).to include('.col-lg-4')
        expect(result).to include('.pricing-card')
        expect(result).to include('h4.mb-4 Starter')
        expect(result).to include('a.btn.btn-outline-primary.w-100[href="pricing.html"] Learn More')
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
