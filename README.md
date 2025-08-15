# Blueprint HTML2Slim

A Ruby gem providing a command-line tool to convert HTML and ERB files to Slim format.

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

## Usage

Convert a single file:
```bash
html2slim index.html
# Creates: index.html.slim
```

Convert with custom output:
```bash
html2slim -o custom.slim index.html
```

Convert multiple files:
```bash
html2slim file1.html file2.erb file3.html.erb
```

Convert and backup original files:
```bash
html2slim -b index.html
# Creates: index.html.slim
# Renames: index.html -> index.html.bak
```

Convert files in a directory recursively:
```bash
html2slim -r ./views
```

Dry run (preview what would be converted):
```bash
html2slim -d file.html
```

## Naming Convention

- `file.html` → `file.html.slim`
- `file.html.erb` → `file.html.slim`
- `file.erb` → `file.slim`

## Options

- `-o, --output FILE` - Output file path (only for single file conversion)
- `-r, --recursive` - Process directories recursively
- `-d, --dry-run` - Show what would be converted without actually converting
- `-f, --force` - Overwrite existing files without prompting
- `-b, --backup` - Backup source files with .bak extension
- `-i, --indent SIZE` - Indentation size in spaces (default: 2)
- `-h, --help` - Show help message
- `-v, --version` - Show version

## Features

- Converts HTML tags to Slim syntax
- Handles HTML attributes, IDs, and classes
- Preserves ERB tags (<%= %> and <% %>)
- Supports nested elements
- Handles void elements correctly
- Preserves comments
- Smart output file naming
- Optional source file backup