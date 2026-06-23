# Claude Switchboard for Alfred

Ask Claude from anywhere on your Mac via Alfred — and instead of a popup that
vanishes the moment you click away, get **persistent, multi-threaded
conversations** whose transcripts land in a Markdown file (or Obsidian note, or
Scratchpad) you can read, fold, search, and pick back up later.

No API key or token billing — requests go through your existing Claude CLI login,
so they use your current Claude plan.

---

## Credits

This is a substantially expanded fork of **[alfred-claude-cli][upstream] by Markus
Löffler** — his workflow is the foundation (the Claude-CLI-from-Alfred idea, the
async Text View rendering, the config scaffolding). This fork keeps that spirit
and builds a full conversation system on top: named parallel threads, folder-
anchored sessions, an archive with restore, a terminal "bridge," and a
configurable output destination. Huge thanks to Markus for the original. MIT
licensed, same as upstream.

[upstream]: https://github.com/markusloffler/alfred-claude-cli

---

## What you get

- **Persistent conversations** — every question continues the thread; follow-ups
  just work (powered by the Claude CLI's own `--resume`).
- **Many threads at once** — keep `work`, `research`, `current`, … going in
  parallel and switch between them; a switchboard shows them most-recent-first.
- **Output where you want it** — a Markdown file by default (pretty rendering,
  foldable, greppable), or an Obsidian note, or Scratchpad.app. Your call.
- **Folder sessions** — anchor a conversation to a folder; its transcript lives
  *in* that folder and carries its own resume info, so the conversation travels
  with the documents it's about.
- **Archive & restore** — retire a conversation without losing it; bring any
  archived one back (no need to remember its name).
- **Bridge to a real terminal** — jump from a quick Alfred ask into a full
  interactive `claude` session, mid-conversation, in one keystroke.

---

## Requirements

**Required**

- macOS, and **Alfred 5** with the **Powerpack**
- The **Claude CLI** (`claude`), installed and logged in — <https://claude.com/claude-code>
- **`jq`** (`brew install jq`)

**Optional (only if you use the matching feature)**

- **Scratchpad.app** — only if you set output to `scratchpad`
- **Ghostty** — the terminal the bridge opens (swap one line for a different terminal)
- An editor of your choice for opening session files (e.g. VS Code, Zed, Obsidian)

---

## Install

1. Download the latest `.alfredworkflow` from **[Releases]** and double-click it
   to import into Alfred. *(Or build from source: `./build.sh`.)*
2. Open the workflow in Alfred → **[∨] Configure Workflow** and set at least the
   **Claude CLI Path** (find yours with `which claude`).
3. Type `cl hello` into Alfred. The answer appears in your chosen output surface.

[Releases]: https://github.com/gpechenik/alfred-claude-switchboard/releases

---

## Configure

Open **Configure Workflow** in Alfred. All settings are optional except the CLI path.

| Setting | Variable | Default | What it does |
|---|---|---|---|
| Claude CLI Path | `CLAUDE_CLI_PATH` | `~/.local/bin/claude` | Path to the `claude` binary (`which claude`). |
| Model | `MODEL` | `sonnet` | Model passed to `claude --model` (`sonnet`, `opus`, `haiku`). |
| Working directory | `WORKING_DIR` | `~` | The folder Claude runs in — its file-tool root, and where the default output file lives. A rich project dir gives Claude context; a bare dir keeps asks fast and light. |
| Default output | `OUTPUT` | *(blank)* | Where plain threads log their transcript — see **[Output](#output-where-your-conversations-go)**. |
| Open session file in | `OPEN_WITH` | *(system default)* | Which app opens a session's file (e.g. `Zed`, `Visual Studio Code`, `Obsidian`). |
| Your emoji | `YOU_EMOJI` | `🤔` | The emoji that marks *your* questions in the transcript. |

---

## Quick start

```
cl what's the difference between TCP and UDP     # ask (continues your current thread)
cls                                              # switchboard: see/switch/manage threads
cls research                                     # type a new name → start a "research" thread
clf ~/projects/acme                              # open a conversation anchored to a folder
clo                                              # jump to the current thread's file
```

---

## Keywords

| Keyword | What it does |
|---|---|
| `cl <question>` | **Ask.** Continues the active thread; the answer lands in your output surface. |
| `cls [filter]` | **Switchboard.** Browse/switch/manage threads (see modifier keys below). |
| `clf <folder>` | **Folder session.** Anchor a conversation to a folder (see [Folder sessions](#folder-sessions)). |
| `clr [name]` | **Clear/retire.** Archive the active thread and start fresh in `[name]` (default `current`). |
| `cla [filter]` | **Archive.** Browse archived conversations and restore them. |
| `clo [name]` | **Open file.** Jump straight to the active (or named) thread's file. |

### `cls` modifier keys

In the `cls` switchboard, each conversation row responds to:

- **↩** — switch to this thread (your next `cl` continues it)
- **⌘↩** — archive it (off the list, recoverable)
- **⌥↩** — open it **live in a terminal** (the bridge — a full interactive `claude` session)
- **⌃↩** — open its file (the folder log, or your output file / Scratchpad)

Typing a filter in `cls` also surfaces matching **archived** threads with a
**♻️ Restore** option, so you can recover one without leaving the switchboard.

---

## Concepts

### Threads & the active thread

A **thread** is one ongoing conversation with its own memory. You can have many.
Exactly one is **active** at a time — whatever `cls`, `clf`, or `clr` last set —
and every `cl` question goes to the active thread until you switch. The default
thread is called `current`.

- **Switch** to an existing thread: `cls` → ↩ on it.
- **Start a new** named thread (leaving the current one intact): `cls` → type a
  new name → ↩.

### Output: where your conversations go

Plain (non-folder) threads send their transcript wherever `OUTPUT` points:

- **blank (default)** → a `claude-log.md` file in your **Working directory** —
  works for everyone, no extra apps. Markdown renders nicely and folds in any editor.
- **`scratchpad`** → [Scratchpad.app](https://sindresorhus.com/scratchpad) (quick,
  append-friendly, but its own app).
- **any file path** → append there. Any `.md` or `.txt`, anywhere — including an
  Obsidian vault note (Obsidian live-reloads on append; no plugin needed). The
  parent folder is created if missing.

Questions are timestamped; answers follow. In a shared file, each question is
tagged with its thread name so parallel conversations stay legible.

### Folder sessions

`clf <folder>` anchors a conversation to a folder:

- Claude **runs in that folder**, so its file tools act on the documents you put there.
- The transcript is written to **`<folder>/claude-session.md`** instead of your
  default output.
- The top of that log carries **resume info** (the session id and a ready-to-paste
  resume command), so the folder is self-describing: run `clf` on it again later —
  even after a reboot — and the conversation resumes from the log itself.

Great for "I'm reviewing these documents and want a conversation that lives with
them." The log also doubles as context: a fresh session opened in the folder can
read it to catch up.

### Archive & restore

Nothing is ever destroyed by moving on:

- `clr` archives the active thread and starts fresh.
- `cls` → **⌘↩** archives any thread.
- `cla` browses the archive; **↩** restores, **⌥↩** peeks an archived folder log
  without restoring.
- Restores and same-name collisions auto-suffix (`acme`, `acme-2`), so a handle is
  never silently overwritten.

### The terminal bridge

Started a quick ask that turned into real work? In `cls`, **⌥↩** on the thread
opens it **live in a terminal** (`claude --resume`), dropping you into the same
conversation with the full interactive UI — in the thread's own folder if it has one.

### Cross-machine note

The conversation transcript that `claude --resume` reads lives in
`~/.claude/projects/…`, which is **local to each machine** (not synced). So:

- **Same machine:** resume by id works — true continuity.
- **Another machine:** the id won't resolve there, but a **folder session's log
  travels** (if the folder is synced), and a fresh session can *read* it to catch
  up. Treat the log as the portable memory; don't try to sync `~/.claude`.

---

## How it works (for the curious / contributors)

- Each `cl` runs `claude -p … --output-format json`, captures the returned
  `session_id`, and passes `--resume <id>` next time. The id is stored per thread.
- State lives under Alfred's workflow cache:
  - `active` — the active thread's name
  - `session.<name>` — that thread's session id (file mtime = last activity, which
    drives the switchboard's recency sort)
  - `session.<name>.title` / `.folder` — sidecars (first-prompt snippet; anchored folder)
  - `archive/session.<name>.<token>*` — archived threads (unique token = never clobbered)
- The `cls`/`cla` keywords are Alfred **Script Filters** that emit items JSON; the
  chosen item's `arg` (e.g. `use:…`, `archive:…`, `restore:…`) is handled by a
  single dispatcher script.
- Output formatting re-levels an answer's Markdown headings beneath the
  `## 🤖 Claude` wrapper so each answer folds as a unit (code fences skipped).

### Files

| File | Role |
|---|---|
| `ask.sh` | The `cl` ask action. |
| `sessions.sh` | The `cls` switchboard (Script Filter). |
| `archived.sh` | The `cla` archive browser (Script Filter). |
| `session-action.sh` | Dispatcher for switchboard/archive actions. |
| `clear-thread.sh` | The `clr` retire action. |
| `open-folder.sh` | The `clf` folder-session opener. |
| `open-session-file.sh` | The `clo` open-file action. |
| `sessions.lib.sh` | Shared helpers (cache paths, sink resolution, archiving, formatting). |

---

## Troubleshooting

- **Answers don't appear?** Check the CLI path in config, and the `ask.log` file in
  the workflow cache (it captures `claude`'s stderr).
- **Switchboard order looks wrong?** The `cls`/`cla` Script Filters do their own
  sorting — leave Alfred's **"Alfred filters results"** *unchecked* on those nodes.
- **`jq: command not found`** — `brew install jq`.
- **A script edit didn't take?** Alfred re-reads the workflow on open; no restart
  needed for script changes. (Editing the workflow's config layout can need a reload.)
- **Editing the scripts:** they target macOS's stock **bash 3.2**. Brace variables
  next to multibyte punctuation (`${x}`), and test with `/bin/bash`, not Homebrew bash 5.

---

## License

MIT — same as the [upstream project][upstream]. See `LICENSE`.
