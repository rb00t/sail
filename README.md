# sail

**Search, stream, and download torrents from the macOS terminal.**

[![macOS](https://img.shields.io/badge/macOS-only-1f2328?style=flat-square&logo=apple&logoColor=white)](#install)
[![public domain](https://img.shields.io/badge/licence-public%20domain-1f2328?style=flat-square)](UNLICENSE)
[![site](https://img.shields.io/badge/site-rb00t.github.io%2Fsail-b6f3c1?style=flat-square&labelColor=1f2328)](https://rb00t.github.io/sail/)

Type a title. Pick a result. It plays.

sail searches up to thirteen torrent sources at once (six by default), streams
in IINA, mpv or VLC, and downloads with a live view of speed, peers and
progress. No account, no remote service. Quit and the temporary video is wiped;
downloads land in `~/Downloads/torrents`.

**[See the captures](https://rb00t.github.io/sail/)**

## Install

Requires macOS. One command installs Homebrew if it is missing, then Python 3
if needed, `fzf`, `webtorrent-cli`, IINA and sail itself:

```bash
curl -fsSL https://raw.githubusercontent.com/rb00t/sail/main/install.sh | bash
```

Run the same command again to upgrade.

## The first 30 seconds

```bash
sail dune          # search, pick a result, then stream or download
sail -s dune       # stream the picked result
sail -d dune       # download the picked result
sail wlist         # saved torrents
sail sources       # choose the sites every search uses
```

The pickers show their keys in the header.

## What you get

- **Up to thirteen sources, one search.** Six are on by default. A source that
  has not answered within six seconds is dropped for that search.
- **A transfer dashboard.** Progress, download and upload speed, a speed
  sparkline, ETA, ratio, and a peer table with each peer's client and how much
  it has. If no bytes arrive, the frame says `no data 42s` instead of pretending
  to work.
- **Subtitles from the torrent.** If the release includes one that matches the
  video, sail streams it alongside. No subtitle service, no API key.
- **Only the files you picked.** A season pack shows a picker; only the chosen
  episodes are written, and an interrupted run leaves a hidden stage, not loose
  files.

## All the details

<details>
<summary><strong>Commands, pipes and exit codes</strong></summary>

| Command | Behavior |
|---|---|
| `sail <query>` | pick a result, then choose stream/download |
| `sail -s <query>` | stream the picked result immediately |
| `sail -d <query>` | download the picked result immediately |
| `sail -l <query>` | list results (seeders, size, source, title) and exit |
| `sail --json <query>` | print results as a JSON array and exit |
| `sail --magnet <link>` | skip the search and use a magnet link directly |
| `sail sources` | choose which sources every search uses |
| `sail wlist [query]` | launch or manage the watchlist (save from results with `ctrl-x`) |
| `sail --version`, `sail -v` | print the installed version |
| `sail -h`, `sail --help` | show usage and exit |

Options may come before or after the query. `--` ends option parsing, so a
query starting with `-` is still searchable: `sail -- -movie`.

`sail -l` is pipe-friendly: it prints one row per result (`seeders`, `size`,
`source`, `title`) and sends the spinner and source warnings to stderr.
`sail --json` emits an array of objects with `id`, `seeders`, `size`, `source`,
`title`, `age`, and `magnet` (a scraped source may leave a `FETCH:<url>`
detail-page marker in `magnet`; sail resolves it only when streaming or
downloading).

`sail -l` exit statuses: `0` success, `1` no results, `2` every source failed,
`3` no sources enabled. An interactive search that fails exits `1`; `ctrl+c`
exits `130`.

Downloads go to `~/Downloads/torrents` (override with `SAIL_DOWNLOAD_DIR`, or
the older `TORRENT_DOWNLOAD_DIR`; the former wins).

Set `SAIL_DEBUG=1` to see each source's own errors (timeouts, parse failures)
after a search that comes back thin, and why a subtitle already in the torrent
failed to fetch. Without it, only the one-line source summary is shown.

</details>

<details>
<summary><strong>Searching, caching and streaming</strong></summary>

A search races every enabled source in parallel and is bounded overall by
`SAIL_SEARCH_TIMEOUT` (default 6 seconds): a source that has not answered by
then is dropped for that search and reported unavailable, instead of being
allowed to define the search time. Repeating a query within `SAIL_CACHE_TTL`
(default 5 minutes) reuses the previous per-source answers, so a near-instant
rerun costs no traffic; `SAIL_NO_CACHE=1` turns that off. Only successful,
non-empty source answers are cached, so a source that failed is retried next
time.

When streaming a torrent with more than one video file (season packs, movies
with extras), sail shows a picker so you choose exactly which one plays. Only
that file is downloaded, never the whole torrent. A single video plays straight
away.

Players are tried in this order: IINA, mpv, VLC. Set `SAIL_PLAYER=iina`, `mpv`,
or `vlc` to pick one; if it is not installed, sail says so and falls back to the
normal order.

If the torrent includes a subtitle file for the video you picked, sail finds and
streams it automatically, preferring an exact filename match, then the same name
plus a language suffix (English first when several languages are present), then
any subtitle file in the same folder as the video. If nothing matches, streaming
continues without one.

A macOS notification fires when a download finishes or fails. Set
`SAIL_NOTIFY=0` to turn notifications off.

If the swarm goes silent (no bytes for 300 seconds), sail stops with a
`stalled: no data received` error instead of hanging forever. Change the
timeout with `SAIL_STALL_TIMEOUT` (seconds; `0` disables the watchdog). Metadata
has its own `SAIL_META_WAIT` (default 300 seconds) per attempt, with one retry.

</details>

<details>
<summary><strong>Sources</strong></summary>

Thirteen sources are built in. Pick and choose the ones every search uses:

```bash
sail sources
```

Type source numbers to toggle them (for example `1 3`), `a` turns all on, `x`
turns all off, `s` saves, and `q` quits without saving. The header marks the
selection `unsaved` as soon as it differs from what is on disk. Your selection
lives in `~/.config/sail/sources.conf`, one source name per line, and applies
globally. You can edit that file by hand; whitespace and `#` comments are
allowed. A missing file means the six defaults; an existing file is
authoritative, so saving an empty list searches no sources. Saves are atomic,
and a typo'd name is reported (`[sources] ignoring unknown source name(s): …`)
instead of silently searching fewer sites.

| Source | Focus | Method |
|---|---|---|
| `tpb` | general | JSON API |
| `yts` | movies | JSON API |
| `eztv` | TV episodes | JSON API |
| `1337x` | general | HTML scrape |
| `knaben` | aggregator, well seeded | HTML scrape |
| `tcsv` | DHT crawled, open data | JSON API |
| `tq` | aggregator | HTML scrape |
| `et` | movies / general | HTML scrape |
| `solid` | general | JSON API |
| `nyaa` | anime / Asian media | HTML scrape |
| `torlock` | general, verified | HTML scrape |
| `tgx` | general | HTML scrape |
| `lime` | general | HTML scrape |

With no config file, searches use `tpb`, `yts`, `eztv`, `knaben`, `tcsv`, and
`solid`. Scraped sources depend on site layout and can break when sites change;
a failing source never blocks the others. When some are down, sail prints a
one-line `[sources] N of M unavailable` summary. Set `SAIL_DEBUG=1` to see each
failure.

</details>

<details>
<summary><strong>Picker, watchlist and downloads</strong></summary>

**Results picker.** The list is sorted by seeders. `ctrl-t` cycles seeders →
size → newest; the header shows the current order. `ctrl-x` saves the
highlighted torrent to the watchlist and reopens the list, so you can save
several in one pass. `enter` selects; `esc` cancels.

After Enter, the mode prompt takes a single key, no Return needed: `s` or
`enter` streams, `d` downloads, `b` goes back to the list (the results are still
in memory, so it does not search again), `q` quits.

**Watchlist.** `ctrl-x` on any result saves it; the list stays open and the
header confirms each save. `sail wlist` shows saved torrents: `enter` launches
one straight to the stream/download prompt (no search), `ctrl-x` removes it,
`esc` quits. An optional query narrows the list: `sail wlist dune`.

Entries live in `~/.config/sail/wlist.tsv` (title, magnet link, date added in
Unix seconds, one per line) and are safe to edit by hand. Scraped results are stored as a
detail-page URL until saved, at which point sail resolves a real magnet link, so
a saved entry still launches after it has left the search results. If the page
is down at save time, the URL is kept and retried at launch. Re-adding a torrent
moves it to the top instead of duplicating it.

**Downloads.** `sail -d` uses the same file picker: `tab` toggles, `ctrl-a`
selects all, `ctrl-d` clears. Bytes are staged in a hidden
`.sail-partial-<pid>-*` directory inside the destination; only the files you
picked are moved into place once complete, so files you did not pick are never
touched; a picked file replaces a same-named file in the destination. An interrupted
download leaves only that hidden stage, which the next download into the same
folder removes. The stage is on the same filesystem, so the final move is a
rename, not a second copy, but make sure the destination has room for the picked
files. A live dashboard tracks progress the same way streaming does.

**Streaming cleanup.** Nothing is kept: torrent metadata is fetched fresh on
every stream, and the downloaded video lives in a temp directory wiped the
moment you quit the player. `ctrl+c` tears the renderer and any torrent/server
child down before exiting, so the next run does not collide with an orphaned
process.

</details>

<details>
<summary><strong>Configuration</strong></summary>

| Variable | Default | Purpose |
|---|---|---|
| `SAIL_DEBUG` | `0` | `1` prints per-source and subtitle errors |
| `SAIL_SOURCES` | `~/.config/sail/sources.conf` | source list path |
| `SAIL_WLIST` | `~/.config/sail/wlist.tsv` | watchlist path |
| `SAIL_DOWNLOAD_DIR` | `~/Downloads/torrents` | download destination |
| `TORRENT_DOWNLOAD_DIR` | — | older name for the destination; `SAIL_DOWNLOAD_DIR` wins |
| `SAIL_PLAYER` | auto (`iina`, `mpv`, `vlc`) | preferred player |
| `SAIL_NOTIFY` | `1` | `0` disables macOS notifications |
| `SAIL_META_WAIT` | `300` | seconds per metadata attempt |
| `SAIL_STALL_TIMEOUT` | `300` | seconds without data before giving up; `0` disables |
| `SAIL_SEARCH_TIMEOUT` | `6` | overall seconds one search may spend; a source still running when it expires is dropped and reported unavailable |
| `SAIL_NO_CACHE` | `0` | `1` disables the search-result cache |
| `SAIL_CACHE_TTL` | `300` | seconds a per-source search answer stays cached; `0` disables |
| `SAIL_CACHE_DIR` | `~/.cache/sail/search` | search-result cache location |
| `SAIL_WTMOD` | discovered | path to the webtorrent module (rarely needed) |
| `SAIL_UTF8_LOCALE` | `en_US.UTF-8` | locale used for multibyte-safe widths |
| `SAIL_ASCII` | `0` | `1` draws ASCII glyphs instead of box-drawing and block characters |

Source, watchlist and download paths accept a leading `~`. `NO_COLOR` drops colour but keeps bold and dim, so
the hierarchy survives a monochrome terminal; `SAIL_ASCII=1` (or `TERM=dumb`)
switches the box, block, spinner and checkmark glyphs to ASCII.

</details>

<details>
<summary><strong>Installer options, uninstall and shell completion</strong></summary>

To see every change without writing anything, add `--dry-run`:

```bash
curl -fsSL https://raw.githubusercontent.com/rb00t/sail/main/install.sh | bash -s -- --dry-run
```

For a reproducible download, set `SAIL_REF` to a tag and verify it with
`SAIL_TARBALL_SHA256` (both apply to the piped installer):

```bash
curl -fsSL https://raw.githubusercontent.com/rb00t/sail/main/install.sh \
  | SAIL_REF=v1.6.0 SAIL_TARBALL_SHA256=<sha256> bash
```

Piping the installer is trust-on-first-use; if you would rather inspect it
first, clone and run it directly. It runs the same installer:

```bash
git clone https://github.com/rb00t/sail.git
cd sail
./install.sh
```

Homebrew installs `fzf`, `webtorrent-cli` and IINA; `sail` itself is copied to
`~/.sail` and symlinked onto PATH. The pickers need `fzf`; if it is missing, sail says so and
points at `sail -l`, which lists results without one. The install goes into a
staging directory and swaps in only after a successful copy, so re-running it is
the upgrade path: an interrupted upgrade leaves the previous version working.
`./install.sh --dry-run` shows the plan without changing anything.

**Uninstall.**

```bash
./uninstall.sh            # removes sail, keeps your sources/watchlist
./uninstall.sh --purge    # also removes ~/.config/sail
```

Homebrew dependencies are left alone; the script prints the command to remove
them too.

**Shell completion.** Tab-completion for the flags, `sources`, and `wlist` lives
in `completions/`. Source the file for your shell, or drop it wherever your shell
loads completions:

```bash
# zsh (e.g. Homebrew's site-functions dir, already on most $fpath entries)
cp completions/_sail "$(brew --prefix)/share/zsh/site-functions/_sail"

# bash (needs bash-completion)
cp completions/sail.bash "$(brew --prefix)/etc/bash_completion.d/sail"
```

`install.sh` copies both in automatically when it finds those directories.

</details>

<details>
<summary><strong>Development and tests</strong></summary>

```bash
bash tests/run-all.sh
```

That runs the Python tests (every network call is mocked) and every shell
suite: watchlist storage and its lock, the tmux-driven pickers, `wt.js` metadata
and staged downloads, the sources UI, the download dashboard, CLI exit statuses,
and installer/uninstaller behavior. Individual suites are `tests/test_*.sh`;
`python3 -m unittest discover tests` runs only the Python ones.

A GitHub Actions workflow ([.github/workflows/ci.yml](.github/workflows/ci.yml))
installs `tmux`, `fzf` and `webtorrent-cli`, then runs the whole suite on macOS. A lint
job runs `shellcheck -x` (sourced libraries included), `node --check`, Python
compilation plus `ruff` (`E4,E7,E9,F`), and `actionlint`. With `CI=1`, a suite
that would otherwise skip for a missing dependency fails instead.

The site in `site/` is static HTML, CSS and JS with no build step, deployed by
[.github/workflows/pages.yml](.github/workflows/pages.yml).

</details>

<details>
<summary><strong>Notes and troubleshooting</strong></summary>

- Streaming needs a reasonably well-seeded torrent; rare files will stutter.
- webtorrent-cli 6.x ships webtorrent 2.8.5, which crashes on *every* torrent add
  when its `uint8-util` dependency resolves to 2.3+ (it passes the info-hash
  string to an API that now only accepts typed arrays; fixed upstream in
  webtorrent 3.x). sail checks for this at startup and repairs it in place.
  `lib/fix-webtorrent.sh` does the same standalone, and
  `brew reinstall webtorrent-cli` undoes the patch.

</details>

## Legal

Only download content you are legally permitted to obtain.

## Links

- [Site](https://rb00t.github.io/sail/)
- [GitHub](https://github.com/rb00t/sail)
- [Codeberg mirror](https://codeberg.org/aasif-alam/sail)
- [Public domain (Unlicense)](UNLICENSE)
