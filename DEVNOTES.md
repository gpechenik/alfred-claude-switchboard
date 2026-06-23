# Developer Notes

Internal notes for building, testing, and releasing this workflow.

## Project layout

```
.
├── workflow/
│   ├── info.plist            # Alfred workflow definition (keywords, actions, config)
│   ├── readme.md             # Workflow "About" text — injected into info.plist by build.sh
│   ├── icon.png              # Workflow icon
│   └── scripts/              # All referenced relatively as ./scripts/<name>.sh
│       ├── sessions.lib.sh   # Shared library: cache paths, sink resolution, threads,
│       │                     #   archiving, Markdown formatting (sourced by the others)
│       ├── ask.sh            # `cl` — ask; runs Claude detached, appends to the output surface
│       ├── sessions.sh       # `cls` — switchboard Script Filter (emits items JSON)
│       ├── archived.sh       # `cla` — archive browser Script Filter
│       ├── session-action.sh # Dispatcher for cls/cla actions (use/new/archive/open/…)
│       ├── clear-thread.sh   # `clr` — archive the active thread, start fresh
│       ├── open-folder.sh    # `clf` — open/resume a folder-anchored session
│       └── open-session-file.sh # `clo` — open a thread's file
├── build.sh                  # Packages workflow/ → dist/*.alfredworkflow
├── CHANGELOG.md              # Release notes (Keep a Changelog) — sliced into the GitHub Release
└── .github/workflows/release.yml  # Builds + publishes the .alfredworkflow on tag push
```

Scripts source siblings via `$(dirname "$0")`, and the plist invokes them as
`./scripts/<name>.sh` — Alfred runs Run Scripts with the bundle as the working
directory, so the bundle is self-contained and relocatable.

## Build and install

From the repo root:

```bash
./build.sh
```

Produces `dist/alfred-claude-switchboard-v<version>.alfredworkflow` (a ZIP). The
version comes from `<key>version</key>` in `workflow/info.plist`. The build injects
the Markdown in `workflow/readme.md` into the plist's `readme` key (the workflow
"About" text), so edit that file rather than the plist string. Install with:

```bash
open dist/alfred-claude-switchboard-v*.alfredworkflow
```

## Make a release

Releases are built and published by `.github/workflows/release.yml` on any
`v*.*.*` tag (`macos-latest` runner → `build.sh` → extracts the matching
`CHANGELOG.md` section → uploads `dist/*.alfredworkflow` to a GitHub Release).

1. Move the items under `## [Unreleased]` in `CHANGELOG.md` into a new
   `## [2.1.0] - YYYY-MM-DD` section (keep an empty `## [Unreleased]` on top).
2. Bump `<key>version</key>` in `workflow/info.plist`.
3. Commit the bump and the changelog.
4. Tag and push — the tag version should match the plist:

   ```bash
   git tag v2.1.0
   git push origin v2.1.0
   ```

> Keep three things in sync: the tag, the plist `version`, and the `CHANGELOG.md`
> heading. The release job derives the version from the plist and pulls notes from
> the `## [<version>]` heading; if no matching section exists it falls back to
> GitHub's auto-generated notes.

## How it runs

The workflow is a set of `cl*` keywords over a shared library and a small set of
files in Alfred's workflow cache. There is no long-running process; state is on disk.

**Asking (`cl <question>`):**

1. The keyword fires `ask.sh`, which resolves the **active thread** (the `active`
   file) and decides where output goes: a folder log (folder session), or the
   plain-thread sink (`OUTPUT` → a file, or Scratchpad).
2. It records the question immediately (instant feedback), then forks a **detached**
   job (`( … ) & disown`) so Alfred returns at once.
3. The job runs `claude -p <prompt> --model <model> [--resume <id>] --output-format
   json`, parses out `.result` and `.session_id`, stores the id for the thread, and
   appends the answer to the output surface.
4. Continuity is the CLI's own `--resume`: the returned `session_id` is stable, so
   it's stored once per thread and reused.

**Switchboard (`cls`) / archive (`cla`):** these are Alfred **Script Filters** that
emit items JSON. Each item's `arg` encodes an action (`use:<name>`, `archive:<name>`,
`open:<name>`, `openfile:<name>`, `restore:<key>`, `openarc:<key>`); modifier keys
swap in a different `arg`. All of them route to the single dispatcher
`session-action.sh`, which performs the action. (Leave **"Alfred filters results"**
unchecked on these nodes — the scripts do their own filtering/sorting.)

## Data model (Alfred workflow cache)

```
active                          # name of the active thread (default "current")
session.<name>                  # thread's Claude session id; file mtime = last activity
session.<name>.title            # first-prompt snippet (shown in cls)
session.<name>.folder           # folder a thread is anchored to (folder sessions)
archive/session.<name>.<token>* # archived threads; <token> is unique → never clobbered
ask.log                         # stderr from the claude calls (debugging)
```

Thread names are sanitized to contain no dot, so any dotted name under `session.`
is a sidecar. A folder session's durable record is its in-folder `claude-session.md`
(with resume info in the header) — the cache just points at it.

## Conventions

- **macOS stock bash 3.2.** Brace variables next to multibyte punctuation (`${x}`),
  and test with `/bin/bash`, not Homebrew bash 5.
- **`jq` is required** (items JSON, parsing the CLI's JSON output, URL-encoding).
- Markdown answers are re-leveled (`nest_headings`) so each answer folds as a unit
  under its `## 🤖 Claude` heading, skipping fenced code blocks.
