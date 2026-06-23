#!/bin/bash

# Run Script action for the `clo` keyword — jump straight to a session's file.
#
#   clo [name]
#
# Opens the active thread's surface (or [name]'s): the folder log for a folder
# session (in your OPEN_WITH app), or Scratchpad for a plain thread. Handy when
# you've navigated away or closed the window and want to get back to it.

set -u
source "$(dirname "$0")/sessions.lib.sh"

req="$(sanitize_name "${1:-}")"
name="${req:-$(active_thread)}"

open_session_file "$name"

folder="$(thread_folder "$name")"
if [[ -n "$folder" ]]; then
  echo "📂 Opened '$name' → $folder/$LOG_NAME"
else
  case "${OUTPUT:-scratchpad}" in
    ""|scratchpad|Scratchpad) echo "📋 Brought Scratchpad forward (thread '$name')" ;;
    *) echo "📂 Opened ${OUTPUT/#\~/$HOME} (thread '$name')" ;;
  esac
fi
