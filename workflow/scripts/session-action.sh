#!/bin/bash

# Run Script action downstream of the `cls` Script Filter (sessions.sh).
# Receives one arg of the form "<action>:<value>" and performs it.
#
#   use:<name>          make <name> the active thread
#   new:<name>          make <name> active and clear any old id (fresh start)
#   archive:<name>      move <name> off the list (timestamped, recoverable)
#   open:<name>         open <name> live in Ghostty (claude --resume <id>)
#   openfile:<name>     open <name>'s file (folder log, or Scratchpad)
#   restore:<key>       bring an archived thread back to the list and activate it
#   openarc:<key>       open an archived (folder) session's log without restoring

set -u
source "$(dirname "$0")/sessions.lib.sh"

CLAUDE_CLI="${CLAUDE_CLI_PATH:-$HOME/.local/bin/claude}"
WORKING_DIR="${WORKING_DIR:-$HOME}"
WORKING_DIR="${WORKING_DIR/#\~/$HOME}"

ARG="${1:-}"
action="${ARG%%:*}"
# restore/openarc carry a raw archive key (<name>.<token>) — do NOT sanitize.
if [[ "$action" == "restore" || "$action" == "openarc" ]]; then
  key="${ARG#*:}"
else
  name="$(sanitize_name "${ARG#*:}")"
  [[ -z "$name" ]] && name="$DEFAULT_THREAD"
fi

case "$action" in
  use)
    set_active_thread "$name"
    echo "▶ Active thread: $name"
    ;;

  new)
    # Fresh start: drop the stored id + title so the next ask begins anew.
    rm -f "$(session_file "$name")" "$(title_file "$name")"
    set_active_thread "$name"
    echo "✦ New thread '$name' — your next 'cl' question starts it"
    ;;

  archive)
    # Timestamped move (never clobbers a prior archive of the same name); the
    # in-folder log of a folder session stays put as the durable record.
    archive_thread "$name"
    [[ "$(active_thread)" == "$name" ]] && set_active_thread "$DEFAULT_THREAD"
    echo "🗄 Archived '$name' (restore via cls)"
    ;;

  restore)
    base="$ARCHIVE/session.$key"
    if [[ ! -e "$base" ]]; then echo "Nothing to restore: $key"; exit 0; fi
    orig="${key%.*}"                       # strip trailing .<ts>
    target="$(free_name "$orig")"          # avoid clobbering a live same-name thread
    mv -f "$base" "$(session_file "$target")" 2>/dev/null
    [[ -e "$base.title"  ]] && mv -f "$base.title"  "$(title_file "$target")"  2>/dev/null
    [[ -e "$base.folder" ]] && mv -f "$base.folder" "$(folder_file "$target")" 2>/dev/null
    set_active_thread "$target"
    if [[ "$target" == "$orig" ]]; then echo "♻️ Restored '$orig'"
    else echo "♻️ Restored '$orig' as '$target' (name was taken)"; fi
    ;;

  open)
    sid="$(cat "$(session_file "$name")" 2>/dev/null)"
    if [[ -z "$sid" ]]; then
      echo "Thread '$name' has no session yet — ask something with 'cl' first"
      exit 0
    fi
    # Graduate the thread to a full interactive session in Ghostty, landing in its
    # own folder if it's folder-anchored, else the configured working directory.
    # Ghostty has no AppleScript dictionary; its documented way to run a command
    # is `open -na Ghostty.app --args -e <cmd>` (see `ghostty --help`). To use a
    # different terminal, swap this one line.
    dir="$(thread_folder "$name")"; [[ -z "$dir" || ! -d "$dir" ]] && dir="$WORKING_DIR"
    inner="cd \"$dir\" && exec \"$CLAUDE_CLI\" --resume $sid"
    open -na Ghostty --args -e zsh -lc "$inner" >/dev/null 2>&1
    echo "👻 Opened '$name' in Ghostty"
    ;;

  openfile)
    open_session_file "$name"
    echo "📂 Opened '$name' file"
    ;;

  openarc)
    ff="$ARCHIVE/session.$key.folder"
    if [[ -f "$ff" ]]; then
      folder="$(cat "$ff")"
      if [[ -f "$folder/$LOG_NAME" ]]; then open_with "$folder/$LOG_NAME"; else open_with "$folder"; fi
      echo "📂 Opened archived log for '${key%.*}'"
    else
      echo "Archived '${key%.*}' was a Scratchpad thread (no file to open)"
    fi
    ;;

  *)
    echo "Unknown action: $ARG"
    ;;
esac
