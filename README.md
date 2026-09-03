# blitz.screenpipe

Omarchy bar chip for multi-bucket [Screenpipe](https://github.com/screenpipe/screenpipe) recording.

Little-Snitch style indicator on the top bar: filled when recording, hollow when paused. Click to switch buckets, pause, or inspect the agent target for the active bucket.

**This plugin ships with zero personal configuration.** Bucket names, window-routing rules, and agent URLs live only under each user's `~/.config/screenpipe/`.

## Install

```bash
omarchy plugin add https://github.com/itz4blitz/blitz-screenpipe.git --enable
```

1. Install the CLI from this repo (or keep your own):

```bash
install -m 755 sp-org ~/.local/bin/sp-org
```

2. Copy examples and edit them for your buckets:

```bash
mkdir -p ~/.config/screenpipe
cp examples/orgs.example.toml ~/.config/screenpipe/orgs.toml
cp examples/org-routes.example.toml ~/.config/screenpipe/org-routes.toml
cp examples/agent-targets.example.json ~/.config/screenpipe/agent-targets.json
$EDITOR ~/.config/screenpipe/orgs.toml
```

3. Generate systemd user units and start the auto-router:

```bash
sp-org write-units
# optional: systemd user service that runs `sp-org watch`
sp-org clear   # pick bucket from your routes
```

4. Put the chip on the bar (hot-reloads `shell.json`):

```json
{ "id": "blitz.screenpipe" }
```

## CLI

```text
sp-org status [--json]
sp-org <org-id>          # pin bucket (manual)
sp-org clear             # back to auto routing
sp-org pause | resume
sp-org agent             # print agent share target for active bucket
sp-org write-units
```

## Screenshots (fake data)

Same pattern as the other `blitz.*` chips — touch a local `DEMO` file (gitignored):

```bash
cd ~/.config/omarchy/plugins/blitz.screenpipe
echo default > DEMO    # recording Client bucket
# echo paused > DEMO   # paused Personal view
omarchy-shell shell rescanPlugins
# open the chip, shoot, then:
rm DEMO
```

Demo payload uses placeholder buckets only (`Work` / `Client` / `Personal`). Your real `orgs.toml` is never read while `DEMO` exists.

## Privacy

- Do not commit `~/.config/screenpipe/orgs.toml`, `org-routes.toml`, or `agent-targets.json`.
- Examples in `examples/` use placeholder names only (`work`, `client`, `personal`).
- Never commit a screenshot taken without `DEMO` if your live labels are personal.
