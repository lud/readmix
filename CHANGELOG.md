# Changelog

All notable changes to this project will be documented in this file.

## [0.8.2] - 2026-09-29

### 🚀 Features

- Support multiple file arguments in CLI entry (_lud_)

### ⚙️ Miscellaneous Tasks

- Limit justfile verbosity on mix.deps (_lud_)

## [0.8.1] - 2026-07-01

### 🐛 Bug Fixes

- Use defp instead of def for app_dep built-in action (_lud_)

## [0.8.0] - 2026-06-30

### 🚀 Features

- Allow readmix to be ran in elixir scripts outside of a mix project (_lud_)

### 📚 Documentation

- Add documentation to public API (_lud_)

## [0.7.2] - 2026-04-15

### ⚙️ Miscellaneous Tasks

- Relax cli_mate dependency requirement (_lud_)

## [0.7.1] - 2026-04-12

### 🚀 Features

- Added silent option for eval block (_lud_)

## [0.7.0] - 2025-11-29

### 🚀 Features

- Added support for direct code evaluation in :eval blocks (_lud_)

## [0.6.3] - 2025-11-17

### 🚀 Features

- Do not create backup dir if nothing to write (_lud_)

## [0.6.2] - 2025-07-10

### 🐛 Bug Fixes

- Correctly provide file and line metadata on eval block (_lud_)

## [0.6.1] - 2025-07-03

### 🚀 Features

- Section formatter will disable force_do_end_blocks (_lud_)

## [0.6.0] - 2025-07-02

### 🚀 Features

- Added the format option to sections to format fenced elixir code (_lud_)

### ⚙️ Miscellaneous Tasks

- Refactor for dialyzer OTP 28 (_lud_)

## [0.4.1] - 2025-04-22

### ⚙️ Miscellaneous Tasks

- Export formatter options (_lud_)
- Export formatter options (_lud_)

## [0.4.0] - 2025-04-19

### 🚀 Features

- Added the eval action in built in generator (_lud_)

### ⚙️ Miscellaneous Tasks

- Update Elixir Github workflow (#4) (_Ludovic Dem_)

## [0.3.0] - 2025-03-28

### 🚀 Features

- Added the section action and extractor (_lud_)

## [0.2.2] - 2025-03-27

### 🚀 Features

- Backups are always enabled by default (_lud_)

### 🐛 Bug Fixes

- Validate actions params schema (_lud_)

## [0.2.1] - 2025-03-25

### 🐛 Bug Fixes

- Use otp_app name in backups directory (_lud_)

## [0.2.0] - 2025-03-25

### 🚀 Features

- Contexts and generators are loaded from config (_lud_)

## [0.1.1] - 2025-03-25

### 🚀 Features

- Initial version (_lud_)

### 🐛 Bug Fixes

- Ensure CLI defined variables have atom keys (_lud_)

### ⚙️ Miscellaneous Tasks

- Relax Elixir version (_lud_)
- Update dependabot config (_lud_)
- Suggest to use in :test too for ElixirLS (_lud_)

