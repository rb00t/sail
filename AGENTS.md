# sail

macOS torrent client. Bash CLI in `bin/sail`, Python helpers in `lib/`, `fzf`
pickers, `webtorrent-cli` for transfers, static site in `site/`.

## Publishing

sail has two homes, and they move together:

| Remote | Repo |
|---|---|
| `origin` | `github.com/rb00t/sail` |
| `codeberg` | `codeberg.org/rb00t/sail` |

Push to both in one command:

```bash
git push origin main && git push codeberg main
```

Done when `git ls-remote origin main` and `git ls-remote codeberg main` print
the same commit.

GitHub Pages serves `site/` through `.github/workflows/pages.yml` on every push
to `main`, so a site edit is live a minute later.

## Keeping the two copies honest

Changes to commands, defaults, or limitations restate themselves in `README.md`
and `site/index.html`; both carry the same description, website, and topics as
the repo About panels. Update all four when one changes:

```bash
gh repo edit rb00t/sail --description "…" --homepage "…"

TOKEN="$(printf 'protocol=https\nhost=codeberg.org\n\n' | git credential fill | sed -n 's/^password=//p')"
curl -X PATCH -u "rb00t:$TOKEN" https://codeberg.org/api/v1/repos/rb00t/sail \
  -H 'Content-Type: application/json' \
  -d '{"description": "…", "website": "…"}'
curl -X PUT -u "rb00t:$TOKEN" https://codeberg.org/api/v1/repos/rb00t/sail/topics \
  -H 'Content-Type: application/json' -d '{"topics": ["…"]}'
```

The Codeberg token is the git credential already in the login keychain; the
`git credential fill` above reads it without prompting for a password.
