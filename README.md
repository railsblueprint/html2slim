# Blueprint HTML2Slim

A comprehensive Ruby gem providing tools to convert HTML/ERB files to Slim format and manipulate Slim templates.

**Online Converter**: Try the web-based version at [https://railsblueprint.com/html2slim](https://railsblueprint.com/html2slim)

## Table of Contents
- [Requirements](#requirements)
- [Installation](#installation)
- [Tools Included](#tools-included)
- [HTML2Slim Converter](#html2slim-converter)
- [SlimTool - Template Manipulation](#slimtool---template-manipulation)
- [Features Overview](#features-overview)
- [Contributing](#contributing)
- [License](#license)

## Requirements

- Ruby 2.7 - 3.4 (compatible with latest Ruby versions)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'blueprint-html2slim'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install blueprint-html2slim
```

## Tools Included

This gem provides two command-line tools:
1. **html2slim** - Convert HTML/ERB files to Slim format
2. **slimtool** - Manipulate and fix existing Slim files

## HTML2Slim Converter

### Programmatic Usage (Ruby)

```ruby
require 'blueprint/html2slim'

# Create a converter instance
converter = Blueprint::Html2Slim::Converter.new

# Convert HTML string
html = '<div class="container"><h1>Hello</h1></div>'
slim = converter.convert(html)
puts slim
# Output: .container
#           h1 Hello

# Convert ERB string
erb = '<%= form_for @user do |f| %>
  <div class="field">
    <%= f.text_field :name %>
  </div>
<% end %>'
slim = converter.convert(erb)
# Output: = form_for @user do |f|
#           .field
#             = f.text_field :name

# With custom indentation (default is 2)
converter = Blueprint::Html2Slim::Converter.new(indent_size: 4)
```

### Command Line Usage

#### Basic Conversion

```bash
# Convert a single file
html2slim index.html
# Creates: index.html.slim

# Convert with custom output
html2slim -o custom.slim index.html

# Convert multiple files
html2slim file1.html file2.erb file3.html.erb
```

#### File Management Options

```bash
# Create backup of original files
html2slim -b index.html
# Creates: index.html.slim
# Renames: index.html -> index.html.bak

# Delete source files after conversion
html2slim -d old_templates/*.erb
# Converts and deletes the original .erb files

# Force overwrite without prompting
html2slim -f existing.html
```

#### Directory Processing

```bash
# Convert files in a directory recursively
html2slim -r ./views

# Convert to target directory (preserves structure)
html2slim -t dist/ -r src/
# Converts src/views/index.html to dist/views/index.html.slim
```

#### Preview and Testing

```bash
# Dry run (preview what would be converted)
html2slim -n file.html

# Custom indentation (default: 2 spaces)
html2slim -i 4 template.html
```

### Naming Conventions

- `file.html` → `file.html.slim`
- `file.html.erb` → `file.html.slim`
- `file.erb` → `file.slim`

### All HTML2Slim Options

- `-o, --output FILE` - Output file path (single file only)
- `-r, --recursive` - Process directories recursively
- `-n, --dry-run` - Preview conversions without modifying files
- `-d, --delete` - Delete source files after successful conversion
- `-t, --target-dir DIR` - Target directory for converted files
- `-f, --force` - Overwrite existing files without prompting
- `-b, --backup` - Create .bak backup of source files
- `-i, --indent SIZE` - Indentation size in spaces (default: 2)
- `-h, --help` - Show help message
- `-v, --version` - Show version

## SlimTool - Template Manipulation

The `slimtool` command provides advanced manipulation capabilities for Slim files.

### 1. Fix Common Syntax Issues

Automatically fix common Slim syntax problems:

```bash
# Fix text starting with forward slash (e.g., span /month)
slimtool fix pricing.slim

# Fix with backup
slimtool fix template.slim --backup

# Preview fixes without modifying
slimtool fix template.slim --dry-run

# Fix multiple files
slimtool fix views/*.slim
```

**Options:**
- `--fix-slashes` - Fix forward slashes in text (default: true)
- `--fix-multiline` - Fix multiline text blocks (default: true)
- `-b, --backup` - Create .bak backup before fixing
- `-n, --dry-run` - Preview changes without modifying files

**What it fixes:**
- Text starting with `/` that would be interpreted as comments
- Multiline text that should use pipe notation
- Common indentation issues

### 2. Extract Content Sections

Extract or remove specific sections from Slim templates:

```bash
# Remove unwanted sections
slimtool extract page.slim --remove head,nav,footer

# Keep only specific sections
slimtool extract page.slim --keep main,article

# Remove outer wrapper div
slimtool extract page.slim --remove-wrapper

# Extract outline (high-level structure only)
slimtool extract page.slim --outline 2
# Extracts only elements at depth 0 and 1

# Extract by CSS selector
slimtool extract page.slim --selector "#content"
slimtool extract page.slim --selector ".main-section"
slimtool extract page.slim --selector "article.featured"

# Custom output file
slimtool extract page.slim --output clean.slim
```

**Options:**
- `--keep SECTIONS` - Keep only specified sections
- `--remove SECTIONS` - Remove specified sections
- `-o, --output FILE` - Output file path
- `--remove-wrapper` - Remove single outer wrapper
- `--outline N` - Extract outline up to depth N
- `--selector CSS` - Extract fragment by CSS selector

**Supported CSS Selectors:**
- Element: `article`, `main`, `div`
- ID: `#content`, `#sidebar`
- Class: `.container`, `.main-section`
- Combined: `article.featured`, `div#main.container`

### 3. Validate Slim Syntax

Check for syntax errors and potential issues:

```bash
# Basic validation
slimtool validate template.slim

# Validate multiple files
slimtool validate views/**/*.slim

# Strict validation (style checks)
slimtool validate template.slim --strict

# Check Rails conventions
slimtool validate app.slim --check-rails

# Combined strict + Rails checks
slimtool validate *.slim --strict --check-rails
```

**Options:**
- `--strict` - Enable strict mode checks
- `--check-rails` - Check Rails best practices

**What it checks:**

**Basic validation:**
- Invalid indentation
- Unclosed brackets
- Empty Ruby code markers (`=` or `-` with no code)
- Text starting with `/` (would be interpreted as comment)

**Strict mode (`--strict`):**
- Tabs in indentation (enforces spaces only)
- Inline styles (suggests using CSS classes)
- Lines exceeding 120 characters
- Deprecated Slim syntax

**Rails checks (`--check-rails`):**
- Static asset links (suggests asset pipeline helpers)
- Hardcoded URLs (suggests Rails path helpers)
- Forms without Rails helpers
- Missing CSRF tokens in forms
- CDN assets that could use asset pipeline

### 4. Convert to Rails Conventions

Transform static Slim templates to use Rails helpers:

```bash
# Create a mappings file for URL conversions
cat > mappings.json << 'EOF'
{
  "/": "root_path",
  "/about": "about_path",
  "/users": "users_path",
  "/login": "new_session_path",
  "/products": "products_path"
}
EOF

# Convert using mappings
slimtool railsify template.slim --mappings mappings.json

# Add CSRF protection to forms
slimtool railsify form.slim --add-csrf --mappings mappings.json

# Convert CDN assets to Rails asset pipeline
slimtool railsify layout.slim --use-assets

# Preview changes
slimtool railsify template.slim --mappings mappings.json --dry-run

# Process multiple files with backup
slimtool railsify views/*.slim --mappings mappings.json --backup
```

**Options:**
- `--mappings FILE` - JSON/YAML file with URL-to-helper mappings
- `--add-helpers` - Convert links to Rails helpers (default: true)
- `--use-assets` - Convert CDN assets to asset pipeline (default: true)
- `--add-csrf` - Add CSRF meta tags to head section
- `-b, --backup` - Create .bak backup before converting
- `-n, --dry-run` - Preview changes without modifying

**What it converts:**
- Static links to Rails path helpers (using your mappings)
- CDN stylesheets to `stylesheet_link_tag`
- CDN scripts to `javascript_include_tag`
- Static forms to include CSRF tokens
- Image paths to use `image_tag` helper

**Note:** Link conversions require explicit mappings - no automatic guessing.

### 5. Extract Hardcoded Links

Find and report all hardcoded links in templates:

```bash
# Display found links
slimtool extract-links template.slim

# Process multiple files
slimtool extract-links views/**/*.slim

# Save results to JSON
slimtool extract-links *.slim -o links.json

# Save in different formats
slimtool extract-links *.slim -o links.yaml --format yaml
slimtool extract-links *.slim -o links.txt --format text

# Find links in entire project
slimtool extract-links app/views/**/*.slim -o project_links.json
```

**Options:**
- `-o, --output FILE` - Save results to file
- `--format FORMAT` - Output format: json, yaml, or text (default: json)

**What it finds:**
- HTML anchor links (`a[href]`)
- Form action URLs
- Asset links (stylesheets, scripts)
- Image sources
- Any hardcoded paths that could use Rails helpers

**Output includes:**
- File location
- Line number
- Link type (anchor, form, asset, image)
- Original URL
- Suggested Rails helper (when applicable)

## Features Overview

### HTML2Slim Converter Features
- ✅ Full HTML5 support
- ✅ ERB template conversion
- ✅ Preserves all attributes and structure
- ✅ Smart ID/class shortcuts (`div#id.class`)
- ✅ Handles void elements correctly
- ✅ Preserves comments
- ✅ Unicode/UTF-8 support
- ✅ Multiline ERB code blocks
- ✅ Custom indentation
- ✅ Batch processing
- ✅ Directory recursion

### SlimTool Features
- ✅ **Syntax Fixing**
  - Text starting with `/` (pipe notation)
  - Multiline text blocks
  - Common indentation issues
  
- ✅ **Content Extraction**
  - Remove unwanted sections
  - Keep specific sections
  - Extract by CSS selector
  - Extract outline by depth
  - Remove wrapper elements
  
- ✅ **Validation**
  - Syntax error detection
  - Style checking (strict mode)
  - Rails convention checking
  - Comprehensive error reporting
  
- ✅ **Rails Integration**
  - Convert links to helpers
  - Asset pipeline integration
  - CSRF token support
  - Form helper suggestions
  
- ✅ **Link Analysis**
  - Find all hardcoded URLs
  - Categorize link types
  - Suggest Rails helpers
  - Multiple output formats

## Examples

### Complete Workflow Example

```bash
# 1. Convert HTML/ERB files to Slim
html2slim -r ./app/views_old -t ./app/views

# 2. Fix any syntax issues
slimtool fix app/views/**/*.slim --backup

# 3. Validate the converted files
slimtool validate app/views/**/*.slim --strict --check-rails

# 4. Extract hardcoded links for analysis
slimtool extract-links app/views/**/*.slim -o links.json

# 5. Create mappings based on found links
cat > url_mappings.json << 'EOF'
{
  "/": "root_path",
  "/dashboard": "dashboard_path",
  "/users": "users_path",
  "/login": "new_session_path"
}
EOF

# 6. Convert to Rails conventions
slimtool railsify app/views/**/*.slim --mappings url_mappings.json --add-csrf

# 7. Final validation
slimtool validate app/views/**/*.slim --check-rails
```

### Cleaning Up Templates

```bash
# Remove all navigation and footer from templates
slimtool extract views/*.slim --remove head,nav,footer,script

# Extract only the main content area
slimtool extract page.slim --selector "#main-content" -o clean.slim

# Get high-level structure for documentation
slimtool extract complex_page.slim --outline 2 -o structure.slim
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

This gem is available as open source under the terms of the [MIT License](LICENSE).