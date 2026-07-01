# Changelog

All notable changes to this project will be documented in this file.

## [0.8.1] - 2026-07-01

### 🐛 Bug Fixes

- Use defp instead of def for app_dep built-in action

## [0.8.0] - 2026-06-30

### 🚀 Features

- Allow readmix to be ran in elixir scripts outside of a mix project

### 📚 Documentation

- Add documentation to public API

## [0.7.2] - 2026-04-15

### ⚙️ Miscellaneous Tasks

- Relax cli_mate dependency requirement

## [0.7.1] - 2026-04-12

### 🚀 Features

- Added silent option for eval block

## [0.7.0] - 2025-11-29

### 🚀 Features

- Added support for direct code evaluation in :eval blocks

## [0.6.3] - 2025-11-17

### 🚀 Features

- Do not create backup dir if nothing to write

## [0.6.2] - 2025-07-10

### 🐛 Bug Fixes

- Correctly provide file and line metadata on eval block

## [0.6.1] - 2025-07-03

### 🚀 Features

- Section formatter will disable force_do_end_blocks

## [0.6.0] - 2025-07-02

### 🚀 Features

- Added the format option to sections to format fenced elixir code

### ⚙️ Miscellaneous Tasks

- Refactor for dialyzer OTP 28

## [0.4.1] - 2025-04-22

### ⚙️ Miscellaneous Tasks

- Export formatter options
- Export formatter options

## [0.4.0] - 2025-04-19

### 🚀 Features

- Added the eval action in built in generator

### ⚙️ Miscellaneous Tasks

- Update Elixir Github workflow (#4)

## [0.3.0] - 2025-03-28

### 🚀 Features

- Added the section action and extractor

## [0.2.2] - 2025-03-27

### 🚀 Features

- Backups are always enabled by default

### 🐛 Bug Fixes

- Validate actions params schema

## [0.2.1] - 2025-03-25

### 🐛 Bug Fixes

- Use otp_app name in backups directory

## [0.2.0] - 2025-03-25

### 🚀 Features

- Contexts and generators are loaded from config

## [0.1.1] - 2025-03-25

### 🚀 Features

- Initial version

### 🐛 Bug Fixes

- Ensure CLI defined variables have atom keys

### ⚙️ Miscellaneous Tasks

- Relax Elixir version
- Update dependabot config
- Suggest to use in :test too for ElixirLS

