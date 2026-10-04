#!/bin/bash
# Boot terminal for i3: show a system summary, then hand over to an interactive
# shell so the window stays usable.
#
# This exists as a script because i3's exec expands $SHELL as an *i3* variable
# (which is undefined), and quoting a nested shell command through i3 exec is
# unreliable. Here $SHELL is expanded by bash, where it means the real thing.

fastfetch

# Hand over to the login shell, replacing this process so no extra shell nests.
exec "${SHELL:-/bin/bash}"