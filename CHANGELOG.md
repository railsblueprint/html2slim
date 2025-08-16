# Changelog

All notable changes to this project will be documented in this file.

## [1.3.1] - 2025-01-16

### Fixed
- **SlimExtractor CSS Selector Support**: 
  - Fixed child combinator selectors (`body > section`) not working
  - Now correctly extracts multiple matching elements instead of just the first
  - Added support for parent-child relationship validation in selectors
- **Improved Content Extraction**:
  - Enhanced default removal list to include `html`, `body`, `script` elements
  - Added automatic cleanup of orphaned comments when sections are removed
  - Fixed extraction logic to handle multiple sections properly
- **Enhanced CSS Selector Parser**:
  - Added `parse_simple_selector()` for individual selector components
  - Implemented `matches_child_selector()` for parent-child verification
  - Added `find_parent_item()` for structure hierarchy navigation

### Changed
- Default remove list now includes: `doctype html head nav header footer script body`
- CSS selector extraction now handles multiple matching elements in single operation
- Orphaned comments are automatically cleaned up during extraction

## [1.3.0] - 2025-01-16

### Added
- **SlimExtractor enhancements**:
  - Extract outline up to specified depth (`--outline N`) for high-level structure analysis
  - Extract fragments by CSS selector (`--selector`) supporting #id, .class, element, and combinations
- **Comprehensive documentation**:
  - Complete README with detailed examples for all commands
  - All command options now have descriptive help text
  - Added workflow examples and use cases
  - Table of contents for easy navigation

### Changed
- Improved command-line help system with detailed option descriptions
- Fixed extraction logic bug where keep/remove functionality wasn't working correctly
- Enhanced help output with categorized examples

### Fixed
- SlimExtractor now correctly handles keep/remove section logic
- Thor deprecation warnings resolved with `exit_on_failure?` method
- RuboCop style violations corrected

## [1.2.0] - 2025-01-16

### Added
- New `slimtool` command-line utility for comprehensive Slim template manipulation
- **SlimFixer**: Automatically fixes common Slim syntax issues
  - Fixes text starting with "/" that would be interpreted as comments (converts to pipe notation)
  - Fixes multiline text blocks using proper pipe notation
  - Supports backup and dry-run modes
- **SlimExtractor**: Extract or remove specific sections from Slim templates
  - Remove unwanted sections (doctype, head, nav, footer, script, etc.)
  - Keep only specified sections (main, article, or any element/class/id)
  - Remove outer wrapper elements
  - Extract outline up to specified depth (high-level structure only)
  - Extract fragments by CSS selector (#id, .class, element, element.class#id)
  - Custom output file support
- **SlimValidator**: Validate Slim syntax and check for potential issues
  - Detects syntax errors (invalid indentation, unclosed brackets, empty Ruby markers)
  - Strict mode: checks for tabs, inline styles, long lines
  - Rails mode: checks for hardcoded URLs, static assets, missing CSRF tokens
  - Comprehensive error and warning reporting
- **SlimRailsifier**: Convert static templates to Rails conventions
  - Configurable link mappings via JSON/YAML files (no automatic guessing)
  - Convert CDN assets to Rails asset pipeline helpers
  - Add CSRF protection meta tags to forms
  - Supports dry-run and backup modes
- **LinkExtractor**: Extract and analyze hardcoded links from templates
  - Find all static HTML links, forms, assets, and images
  - Categorize link types and suggest Rails helper conversions
  - Multiple output formats (JSON, YAML, text)
  - Batch processing of multiple files
- Comprehensive test suite for all new SlimTool features

### Changed
- Updated gem to include both `html2slim` and `slimtool` executables
- Rails link conversions now require explicit mappings (removed automatic fallback guessing)
- Improved command-line help with detailed examples and option descriptions

## [1.1.0] - 2025-01-16

### Added
- Unicode/UTF-8 character support (CJK, emoji, European accents, Cyrillic, Arabic, Hebrew)
- Multiline ERB code block handling using `ruby:` blocks for better Slim syntax
- Support for inline arrays with chained methods in ERB blocks

### Fixed
- Text starting with "/" now uses pipe notation to avoid being interpreted as Slim comments
- Multiline Ruby code (hashes, arrays, method calls) now generates valid Slim syntax
- UTF-8 encoding issues in CLI tool when reading and writing files

### Changed
- Improved handling of complex ERB structures with proper indentation
- Better detection and formatting of multiline ERB blocks
- Updated RuboCop configuration to disable unnecessary cops

## [1.0.0] - 2024-01-01

### Added
- Initial release of blueprint-html2slim
- HTML to Slim conversion with full HTML5 support
- ERB template support with proper Ruby code handling
- Smart file naming conventions (.html → .html.slim, .erb → .slim)
- Backup option for source files
- Recursive directory processing
- Dry-run mode for previewing conversions
- Custom output path support
- Force overwrite option
- Delete source files after conversion
- Target directory support with structure preservation
- Custom indentation size support
- Comprehensive test suite with RSpec
- RuboCop integration for code quality