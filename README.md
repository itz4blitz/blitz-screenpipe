# blitz.screenpipe

Omarchy bar chip for [Screenpipe](https://github.com/screenpipe/screenpipe) with an **inbox → file later** workflow.

One local recorder writes to an inbox folder. When a call starts, the chip opens and tells you. **Nothing is copied into a labeled destination until you file the meeting.** Optional route hints can suggest a destination; they never auto-file.

## Install

```bash
omarchy plugin add https://github.com/itz4blitz/blitz-screenpipe.git --enable
install -m 755 sp-org ~/.local/bin/sp-org
mkdir -p ~/.config/screenpipe
cp examples/orgs.example.toml ~/.config/screenpipe/orgs.toml
# edit destinations — keep [inbox] as the only live recorder
sp-org ensure
```

## Flow

1. Inbox recorder always on (or pause from the chip).
2. Call detected → bar pops open: “recording to inbox”.
3. Call ends → meeting appears under **Unfiled**.
4. Click a destination → exports that meeting into that folder only then.

```bash
sp-org status
sp-org file 41 work
sp-org pick-dir client
```

## Screenshots (fake data)

```bash
echo default > DEMO    # in-call view
# echo pending > DEMO  # unfiled list
omarchy-shell shell rescanPlugins
rm DEMO
```

## Privacy

Ship no personal `orgs.toml` / routes / filings. Examples use `work` / `client` / `personal` only.
