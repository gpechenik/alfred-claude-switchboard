# Claude Switchboard

Persistent, multi-threaded Claude conversations from Alfred — logged to Markdown
files you keep. Uses your existing Claude CLI login (no API key / token billing).

A substantially expanded fork of [alfred-claude-cli](https://github.com/markusloffler/alfred-claude-cli)
by Markus Löffler.

## Keywords

- `cl <question>` — ask (continues the active thread)
- `cls [filter]` — switchboard: switch (↩) · archive (⌘↩) · open in terminal (⌥↩) · open file (⌃↩)
- `clf <folder>` — folder session: anchor a conversation to a folder, logged in it
- `clr [name]` — archive the active thread and start fresh
- `cla [filter]` — browse the archive; restore (↩) · peek (⌥↩)
- `clo [name]` — open the active (or named) thread's file

## Setup

Open **Configure Workflow** and set the **Claude CLI Path** (`which claude`).
Optionally set the model, working directory, output destination (a Markdown file,
an Obsidian note, or `scratchpad`), and which app opens session files.

Requires the Claude CLI, `jq` (`brew install jq`), and Alfred 5 with the Powerpack.

Full docs: <https://github.com/gpechenik/alfred-claude-switchboard>
