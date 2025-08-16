# Changelog

All notable changes to this project will be documented in this file.

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
- HTML to Slim conversion
- ERB template support
- Smart file naming conventions
- Backup option for source files
- Recursive directory processing
- Dry-run mode
- Custom output path support