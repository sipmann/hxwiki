#!/bin/sh
# Copyright (C) 2026 Tom Waddington
# Copyright (C) 2026 Sipmann
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Adapted from nrepl.hx's tests/run-all.sh
# (https://github.com/waddie/nrepl.hx/blob/main/tests/run-all.sh),
# licensed AGPL-3.0-or-later.
#
# Run the headless Steel test suites. Must be run from the repo root:
#   sh tests/run-all.sh
#
# The bare steel CLI exits 0 even when a piped script raises an uncaught
# error, so success is detected by the SUITE-PASS sentinel each suite prints
# via harness.scm's summarize! -- a suite that crashes or has failing checks
# never prints it.

fail=0
for t in tests/test-*.scm; do
    out=$(steel < "$t" 2>&1)
    if printf '%s\n' "$out" | grep -q "^SUITE-PASS"; then
        printf '%s\n' "$out" | grep "^SUITE-PASS" | sed "s|^|$t: |"
    else
        echo "$t: FAIL"
        printf '%s\n' "$out" | grep -v "^=> " | sed 's/^/    /'
        fail=1
    fi
done
exit $fail
