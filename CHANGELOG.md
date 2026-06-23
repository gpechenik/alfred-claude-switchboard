# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-06-23

Forked and substantially expanded as **Claude Switchboard** (Graham Pechenik),
building on Markus Löffler's alfred-claude-cli.

### Added

- **Named, parallel threads** — keep many conversations going at once; an active
  thread that every `cl` continues.
- **`cls` switchboard** (Script Filter) — switch (↩), archive (⌘↩), open live in a
  terminal (⌥↩, the "bridge"), or open the thread's file (⌃↩); recency-sorted.
- **Folder sessions** (`clf <folder>`) — anchor a conversation to a folder; the
  transcript is logged to `<folder>/claude-session.md` with self-describing resume
  info at the top, so it travels with the documents.
- **Archive & restore** — `clr` retires the active thread (non-destructive); `cla`
  browses the archive and restores; collisions auto-suffix.
- **`clo`** — jump straight to a thread's file.
- **Configurable output** (`OUTPUT`) — a Markdown file (default), an Obsidian note,
  any `.md`/`.txt`, or Scratchpad. Removes the hard Scratchpad dependency.
- **`OPEN_WITH` / `WORKING_DIR`** config; per-question timestamps; foldable Markdown
  (answer headings re-leveled to nest under the answer).

### Changed

- Replaced the single Text-View renderer with persistent, file-backed conversations.
- Keyword scheme is now the `cl*` family (`cl`, `cls`, `clr`, `clf`, `cla`, `clo`).

## [1.1.0] - 2026-06-21

### Added

- Press ⏎ on a displayed answer to copy it to the clipboard

### Changed

- Improved icon
- Changed keyword to "cla"
- Improved styling of output

## [1.0.0] - 2026-06-20

### Added

- Initial release of the Claude CLI Alfred workflow: type `ca <prompt>` to run
  Claude in the background and render the answer in an Alfred Text View.
