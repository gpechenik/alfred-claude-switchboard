#!/bin/bash

# Run Script action for the `clr` keyword — CLEAR/retire the active conversation.
#
#   clr [name]
#
# Archives the currently active thread (timestamped, preserved, restorable via
# the cls switchboard) and switches to [name], starting it fresh. Non-destructive:
# nothing is deleted, so you never lose a conversation just by moving on.
#   • clr            → archive current, start a fresh "current"
#   • clr review     → archive current, switch to a fresh "review"
#
# For an *additive* new thread that leaves the current one ACTIVE too, use the
# cls switchboard and type a new name instead (that doesn't touch the current).

set -u
source "$(dirname "$0")/sessions.lib.sh"

OLD="$(active_thread)"
had_session=0
[[ -e "$(session_file "$OLD")" ]] && had_session=1

archive_thread "$OLD"          # no-op if the thread had nothing yet

req="$(sanitize_name "${1:-}")"
NEW="${req:-$DEFAULT_THREAD}"
set_active_thread "$NEW"

# Because OLD was moved to the archive, reusing its name (the default case) now
# starts genuinely fresh; switching to an existing live thread just resumes it.
if [[ "$had_session" -eq 1 ]]; then
  echo "🧹 Archived '$OLD' (restore via cls) → now in '$NEW'"
else
  echo "▶ Now in '$NEW'"
fi
