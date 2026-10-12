#!/usr/bin/env bash
# CI gate for the bundled plugin bridge. The ONE copy of this logic —
# .github/workflows/gate.yml and publish.yml both call this script, because
# two inline copies of a thirteen-line shell block is two places to forget.
#
# Why this is a script and not three `run:` lines: every one of its exits has
# to be able to REPORT what happened. Four consecutive red runs of this release
# were diagnosed by elimination, because the failing step printed nothing that
# said where it stopped — and the run log is not readable without credentials.
# The job summary IS (check-runs -> output.summary, no auth), so every exit
# path below goes through `fail`, which writes there and emits ::error::.
#
# What is actually asserted: the freshly built bridge must satisfy the whole
# behavioural suite (31 faces render, no stubs, model facts match the source
# tables, page citations, version consistency, content invariants).
#
# What is NOT asserted, and why: byte-identity with plugin/vendor/BUILD.json.
# That bundle is a gitignored build artifact, so a fresh checkout does not
# contain it; this step has to build one, and a build is only reproducible
# under the exact toolchain that produced it. The installer's `latest` is a
# moving alias and cli.moonbitlang.com prunes version-pinned tarballs (measured
# 2026-10-12: core-latest.tar.gz answers 206 to a range request, and
# core-0.1.20261012.tar.gz answers 403), so CI cannot freeze its toolchain.
# The byte pin is therefore a LOCAL tripwire against an edited or stale
# bundled copy, and the summary prints both hashes every run so the difference
# is visible rather than silent. Do not "fix" that by pinning the installer:
# the pinned tarball is not retained.

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1

say() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
  fi
  return 0
}

# The single exit path. Name the thing that died, write it where a credential-
# free API call can read it, then fail the step.
fail() {
  say ""
  say '```'
  say "**$1**"
  echo "::error::$1"
  exit 1
}

BUILT_WITH=$(grep -o 'moon [0-9][0-9.]*' plugin/vendor/BUILD.json | head -1)
MOON_NOW=$(moon version 2>&1 | head -1)

say "## plugin · anti-drift"
say ""
say "| | toolchain |"
say "|---|---|"
say "| recorded in \`plugin/vendor/BUILD.json\` | \`$BUILT_WITH\` |"
say "| on this runner | \`$MOON_NOW\` |"
say ""
say '```text'

moon build --target js \
  || fail "moon build --target js failed on this runner"
node -e "require('fs').copyFileSync('_build/js/debug/build/cmd/jsoncli/jsoncli.js','plugin/vendor/jsoncli.js')" \
  || fail "the freshly built bridge could not be copied into plugin/vendor/"

FRESH_BYTES=$(wc -c < plugin/vendor/jsoncli.js | tr -d ' ')
FRESH_SHA=$(sha256sum plugin/vendor/jsoncli.js | cut -c1-16)
PIN_BYTES=$(sed -n 's/.*"bytes": *\([0-9]*\).*/\1/p' plugin/vendor/BUILD.json)
PIN_SHA=$(sed -n 's/.*"bundleSha256": *"\([0-9a-f]*\)".*/\1/p' plugin/vendor/BUILD.json | cut -c1-16)

say "freshly built bridge : $FRESH_BYTES bytes  sha ${FRESH_SHA}…"
say "pinned in BUILD.json: $PIN_BYTES bytes  sha ${PIN_SHA}…"
if [ "$FRESH_SHA" = "$PIN_SHA" ]; then
  say "-> byte-identical to the pin."
else
  say "-> NOT byte-identical to the pin. Expected when the runner's moon is not"
  say "   the one BUILD.json was pinned with (see the table above). The byte pin"
  say "   is a local tripwire; CI asserts the behavioural suite below instead."
fi
say '```'
say ""

OUT=$(node plugin/tools/validate-plugin.mjs 2>&1)
RC=$?
printf '%s\n' "$OUT"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '```text\n%s\n```\n' "$OUT" >> "$GITHUB_STEP_SUMMARY"
fi

[ "$RC" -eq 0 ] \
  || fail "plugin anti-drift harness reported failures — the FAIL lines above name the check"

say "anti-drift harness: all checks passed (the block above states how many)."
exit 0