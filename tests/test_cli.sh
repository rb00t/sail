#!/usr/bin/env bash
# CLI contract tests: help/version exit statuses, empty-query handling, and
# path expansion. These paths never touch the network.
set -euo pipefail

cd "$(dirname "$0")/.."

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

W="$(mktemp -d)"
cleanup() { rm -rf "$W"; }
trap cleanup EXIT

run() {  # run sail, capture stdout+stderr and exit status
    local rc=0
    "$@" >"$W/out" 2>"$W/err" || rc=$?
    printf '%s' "$rc"
}

# --- 1. -h is a successful request for help -------------------------------
RC="$(run bash bin/sail -h)"
if [ "$RC" -eq 0 ] \
   && grep -q 'sail <query>' "$W/out" \
   && grep -q 'sail -h' "$W/out"; then
    ok "-h prints usage and exits 0"
else
    fail "-h: rc=$RC out=[$(tr '\n' ' ' < "$W/out")]"
fi

# --- 2. no query / blank query / unknown flag are usage errors -------------
RC="$(run bash bin/sail)"
if [ "$RC" -eq 1 ]; then ok "no arguments: exit 1"; else fail "no arguments: rc=$RC"; fi
RC="$(run bash bin/sail "")"
if [ "$RC" -eq 1 ]; then ok "empty query: exit 1"; else fail "empty query: rc=$RC"; fi
RC="$(run bash bin/sail -d "")"
if [ "$RC" -eq 1 ]; then ok "empty -d query: exit 1"; else fail "empty -d query: rc=$RC"; fi
RC="$(run bash bin/sail -x)"
if [ "$RC" -eq 1 ]; then ok "unknown flag: exit 1"; else fail "unknown flag: rc=$RC"; fi

# --- 3. --version / -v still exit 0 ---------------------------------------
RC="$(run bash bin/sail --version)"
if [ "$RC" -eq 0 ] && grep -Eq '^sail [0-9]+\.[0-9]+\.[0-9]+$' "$W/out"; then
    ok "--version prints the version and exits 0"
else
    fail "--version: rc=$RC out=[$(cat "$W/out")]"
fi
RC="$(run bash bin/sail -v)"
if [ "$RC" -eq 0 ] && grep -Eq '^sail [0-9]+\.[0-9]+\.[0-9]+$' "$W/out"; then
    ok "-v prints the version and exits 0"
else
    fail "-v: rc=$RC out=[$(cat "$W/out")]"
fi

# --- 3b. --help is quiet and documents the non-interactive flags ----------
RC="$(run bash bin/sail --help)"
if [ "$RC" -eq 0 ] && [ ! -s "$W/err" ] \
   && grep -q -- '--magnet' "$W/out" \
   && grep -q -- '--json' "$W/out" \
   && grep -q -- '-l, --list' "$W/out"; then
    ok "--help prints usage, new flags, no option-parser noise"
else
    fail "--help: rc=$RC err=[$(cat "$W/err")]"
fi

# --- 3c. help/version must not touch ~/.cache/sail ------------------------
# (the old script wiped the cache before parsing anything)
mkdir -p "$W/home/.cache/sail"
printf 'keep me\n' > "$W/home/.cache/sail/marker"
RC="$(run env HOME="$W/home" bash bin/sail --version)"
RC2="$(run env HOME="$W/home" bash bin/sail -h)"
if [ "$RC" -eq 0 ] && [ "$RC2" -eq 0 ] && [ -f "$W/home/.cache/sail/marker" ]; then
    ok "help/version leave ~/.cache/sail alone"
else
    fail "help/version deleted the cache (rc=$RC/$RC2)"
fi

# --- 3d. a normal run keeps the search cache and clears legacy entries ----
mkdir -p "$W/home2/.cache/sail/search" "$W/home2/.cache/sail/legacy"
printf 'keep\n' > "$W/home2/.cache/sail/search/answer"
printf 'old\n' > "$W/home2/.cache/sail/legacy/file"
RC=0
printf 'q' | env HOME="$W/home2" SAIL_SOURCES="$W/home2/sources.conf" \
    bash bin/sail sources >/dev/null 2>&1 || RC=$?
if [ "$RC" -eq 0 ] \
   && [ -f "$W/home2/.cache/sail/search/answer" ] \
   && [ ! -e "$W/home2/.cache/sail/legacy" ]; then
    ok "normal run keeps the search cache, clears legacy entries"
else
    fail "normal run touched the search cache or kept legacy (rc=$RC)"
fi

# --- 3e. invalid magnet links are rejected before any work -----------------
RC="$(run bash bin/sail --magnet 'https://example.com/not-a-magnet')"
if [ "$RC" -eq 1 ] && grep -q 'not a magnet link' "$W/err"; then
    ok "invalid --magnet exits 1 with a clear error"
else
    fail "invalid --magnet: rc=$RC err=[$(cat "$W/err")]"
fi
RC="$(run bash bin/sail --magnet 'magnet:?xt=urn:btih:abc' extra)"
if [ "$RC" -eq 1 ]; then
    ok "--magnet with a query is a usage error"
else
    fail "--magnet + query: rc=$RC"
fi

# --- 3e. --magnet -l/--json print the link without a network search --------
RC="$(run bash bin/sail --magnet 'magnet:?xt=urn:btih:abc&dn=Test%20Title' -l)"
if [ "$RC" -eq 0 ] && grep -q 'Test Title' "$W/out" \
   && grep -q 'magnet:?xt=urn:btih:abc' "$W/out"; then
    ok "--magnet -l prints the title and link"
else
    fail "--magnet -l: rc=$RC out=[$(cat "$W/out")] err=[$(cat "$W/err")]"
fi
RC="$(run bash bin/sail --json --magnet 'magnet:?xt=urn:btih:abc&dn=Test')"
if [ "$RC" -eq 0 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d[0]["magnet"].startswith("magnet:") else 1)' "$W/out"; then
    ok "--json --magnet prints a JSON array"
else
    fail "--json --magnet: rc=$RC out=[$(cat "$W/out")]"
fi

# --- 3f. no enabled sources is its own status and message -----------------
: > "$W/no-sources.conf"
RC="$(run env SAIL_SOURCES="$W/no-sources.conf" bash bin/sail -l anything)"
if [ "$RC" -eq 3 ] && grep -q 'no sources enabled' "$W/err"; then
    ok "-l with no enabled sources exits 3"
else
    fail "-l no sources: rc=$RC err=[$(cat "$W/err")]"
fi

# --- 4. an empty watchlist is a clean no-op (and SAIL_WLIST is honored) -----
RC="$(run env SAIL_WLIST="$W/none.tsv" bash bin/sail wlist)"
if [ "$RC" -eq 0 ] && grep -q 'watchlist is empty' "$W/out"; then
    ok "empty watchlist exits 0"
else
    fail "empty watchlist: rc=$RC out=[$(cat "$W/out")]"
fi

# --- 4b. launching from the watchlist keeps the saved magnet --------------
# The watchlist picker sets MAGNET for the launch path. The option parser
# runs afterwards and must not reset it: an empty id makes webtorrent fail
# with "Invalid torrent identifier" instead of opening the saved torrent.
mkdir -p "$W/fakebin" "$W/downloads"
MAG='magnet:?xt=urn:btih:1111111111111111111111111111111111111111&dn=Watchlisted'
cat > "$W/fakebin/fzf" <<'FZF'
#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
printf '\n1\t just now Watchlisted Title\n'
FZF
cat > "$W/fakebin/osascript" <<'OSA'
#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
printf '%s\n' "$SAIL_DOWNLOAD_DIR"
OSA
cat > "$W/fakebin/webtorrent" <<'WT'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$SAIL_WT_ARGS"
exit 1
WT
chmod +x "$W/fakebin/fzf" "$W/fakebin/osascript" "$W/fakebin/webtorrent"
printf 'Watchlisted Title\t%s\t1760000000\n' "$MAG" > "$W/wl.tsv"
RC="$(printf 'd\n' | run env PATH="$W/fakebin:$PATH" HOME="$W/home" \
    SAIL_WLIST="$W/wl.tsv" SAIL_DOWNLOAD_DIR="$W/downloads" \
    SAIL_WT_ARGS="$W/wt.args" SAIL_WTMOD="$W/no-such-module" \
    bash bin/sail wlist)"
if [ "$(sed -n '1p' "$W/wt.args" 2>/dev/null)" = "$MAG" ]; then
    ok "watchlist launch passes the saved magnet through"
else
    fail "watchlist launch sent [$(sed -n '1p' "$W/wt.args" 2>/dev/null)] to webtorrent (rc=$RC)"
fi

# --- 5. ~ in path overrides expands to $HOME ------------------------------
awk '/^expand_tilde\(\) \{/ { copy = 1 } copy { print } copy && /^\}/ { exit }' \
    bin/sail > "$W/expand.sh"
# shellcheck disable=SC1090
# shellcheck source=/dev/null
. "$W/expand.sh"
# shellcheck disable=SC2088  # the literal ~ is what expand_tilde exists for
if [ "$(expand_tilde '~/Videos')" = "$HOME/Videos" ] \
   && [ "$(expand_tilde '~')" = "$HOME" ] \
   && [ "$(expand_tilde '/tmp/x')" = "/tmp/x" ]; then
    ok "expand_tilde handles ~, ~/path, and plain paths"
else
    fail "expand_tilde: [$(expand_tilde '~/Videos')] [$(expand_tilde '~')]"
fi

# --- 6. the result sort cycle (ctrl-t) uses the right key each time -------
awk '/^sorted_results\(\) \{/ { copy = 1 } copy { print } copy && /^\}/ { exit }' \
    bin/sail > "$W/sorted.sh"
# shellcheck source=/dev/null
. "$W/sorted.sh"
printf '0\t10\t2.0GB\ttpb\tB\t1d ago\tm0\n1\t50\t500MB\ttpb\tA\t2h ago\tm1\n2\t5\t10GB\ttpb\tC\t3mo ago\tm2\n' \
    > "$W/rows.tsv"
S_SEED="$(sorted_results "$W/rows.tsv" seed | cut -f1 | paste -sd, -)"
S_SIZE="$(sorted_results "$W/rows.tsv" size | cut -f1 | paste -sd, -)"
S_AGE="$(sorted_results "$W/rows.tsv" age | cut -f1 | paste -sd, -)"
if [ "$S_SEED" = "1,0,2" ] && [ "$S_SIZE" = "2,0,1" ] \
   && [ "$S_AGE" = "1,0,2" ]; then
    ok "sorted_results orders by seeders, size, and age"
else
    fail "sorted_results: seed=$S_SEED size=$S_SIZE age=$S_AGE"
fi

# wlist storage uses the same expansion
# shellcheck disable=SC2088
if [ "$(SAIL_WLIST='~/sail-test.tsv' bash -c '. lib/wlist.sh; wlist_file')" \
     = "$HOME/sail-test.tsv" ]; then
    ok "wlist_file expands a leading ~"
else
    fail "wlist_file did not expand ~"
fi

# --- 7. the mode prompt offers `b`, takes one key, and sanitizes titles ----
if grep -q "stream, download, or back? \[S/d/b/q\]" bin/sail \
   && grep -q 'read -r -n 1 answer' bin/sail; then
    ok "mode prompt takes one key and offers back"
else
    fail "mode prompt is missing the single-key/back change"
fi
# `b` must re-enter the picker without re-running the search
if grep -q '^        pick_result$' bin/sail \
   && [ "$(grep -c '^    do_search$' bin/sail)" -eq 1 ]; then
    ok "back re-opens the picker without a second search"
else
    fail "search and pick are not separated"
fi
# a title with an escape must be cleaned before it is echoed
if grep -q "tr -d '\\\\000-\\\\010\\\\013-\\\\037\\\\177'" bin/sail; then
    ok "titles are stripped of control characters before display"
else
    fail "no control-character strip before display"
fi

# --- 8. one glyph set, switched in one place ------------------------------
if grep -qF "G_TL='+'" bin/sail && grep -qF "G_FULL='#'" bin/sail; then
    ok "SAIL_ASCII selects an ASCII glyph set"
else
    fail "no ASCII glyph set in bin/sail"
fi
# the pattern is literal text in the file, so single quotes are correct here
# shellcheck disable=SC2016
GLYPH_USE="$(grep -cF '"$G_TL" "$G_H"' lib/dashboard.sh || true)"
if ! grep -q "printf '  ╭─" lib/dashboard.sh && [ "$GLYPH_USE" -ge 1 ]; then
    ok "dashboard draws from the glyph set, not literals"
else
    fail "dashboard still hardcodes box glyphs"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
