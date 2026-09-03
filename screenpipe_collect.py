#!/usr/bin/env python3
"""blitz.screenpipe collector — thin wrapper around sp-org (config-driven)."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


def sp(*args: str) -> subprocess.CompletedProcess[str]:
    bin_path = shutil.which("sp-org")
    if not bin_path:
        local = Path.home() / ".local/bin/sp-org"
        bin_path = str(local) if local.exists() else "sp-org"
    return subprocess.run(
        [bin_path, *args],
        text=True,
        capture_output=True,
        check=False,
    )


def status_json() -> dict:
    r = sp("status", "--json")
    if r.returncode != 0 or not r.stdout.strip():
        return {
            "ready": False,
            "paused": True,
            "recording": False,
            "mode": "unknown",
            "org": "",
            "label": "Screenpipe",
            "short": "?",
            "reason": (r.stderr or r.stdout or "sp-org failed").strip()[:200],
            "orgs": [],
            "hint": "Install sp-org and create ~/.config/screenpipe/orgs.toml from examples/",
        }
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"ready": False, "hint": "bad json from sp-org", "orgs": []}


def main(argv: list[str]) -> int:
    if len(argv) <= 1 or argv[1] in ("status", "collect"):
        print(json.dumps(status_json()))
        return 0

    action = argv[1]
    if action == "action":
        if len(argv) < 3:
            print(json.dumps({"ok": False, "error": "missing action"}))
            return 1
        sub = argv[2]
        r = sp(sub)
        st = status_json()
        st["ok"] = r.returncode == 0
        if r.returncode != 0:
            st["error"] = (r.stderr or r.stdout or "failed").strip()[:300]
        print(json.dumps(st))
        return 0 if r.returncode == 0 else 1

    if action == "demo":
        # Placeholder-only payload for screenshots. No real org names.
        print(
            json.dumps(
                {
                    "ready": True,
                    "paused": False,
                    "recording": True,
                    "mode": "auto",
                    "org": "client",
                    "desired": "client",
                    "detected": "client",
                    "reason": "focus:slack:client",
                    "label": "Client",
                    "short": "Cli",
                    "port": 3031,
                    "api_url": "http://127.0.0.1:3031",
                    "agent_share": True,
                    "hermes_share": True,
                    "agent": {
                        "label": "Client agent",
                        "api_url": "http://127.0.0.1:3031",
                        "note": "Shares summaries only when you ask.",
                        "share": True,
                    },
                    "hermes": {
                        "label": "Client agent",
                        "api_url": "http://127.0.0.1:3031",
                        "note": "Shares summaries only when you ask.",
                        "share": True,
                    },
                    "override": None,
                    "orgs": [
                        {
                            "id": "work",
                            "label": "Work",
                            "short": "Wrk",
                            "port": 3030,
                            "selected": False,
                            "recording": False,
                            "unit_active": False,
                            "health": False,
                            "agent_share": False,
                            "agent": {"share": False},
                            "hermes": {"share": False},
                        },
                        {
                            "id": "client",
                            "label": "Client",
                            "short": "Cli",
                            "port": 3031,
                            "selected": True,
                            "recording": True,
                            "unit_active": True,
                            "health": True,
                            "agent_share": True,
                            "agent": {"share": True, "label": "Client agent"},
                            "hermes": {"share": True, "label": "Client agent"},
                        },
                        {
                            "id": "personal",
                            "label": "Personal",
                            "short": "Me",
                            "port": 3032,
                            "selected": False,
                            "recording": False,
                            "unit_active": False,
                            "health": False,
                            "agent_share": False,
                            "agent": {"share": False},
                            "hermes": {"share": False},
                        },
                    ],
                }
            )
        )
        return 0

    print(json.dumps(status_json()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
