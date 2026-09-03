#!/usr/bin/env python3
"""blitz.screenpipe collector — thin wrapper around sp-org (config-driven).

Touch a DEMO file in this directory to force placeholder payload for README shots:
  echo > DEMO          # default recording view
  echo paused > DEMO   # paused view
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


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


def demo_view() -> str:
    flag = HERE / "DEMO"
    try:
        if flag.is_file():
            return flag.read_text(encoding="utf-8").strip() or "default"
    except OSError:
        pass
    return ""


def demo_payload(view: str = "default") -> dict:
    """Placeholder-only names. Safe for public screenshots."""
    paused = view in ("paused", "idle")
    recording = not paused
    active = "client" if recording else "personal"
    orgs = [
        {
            "id": "work",
            "label": "Work",
            "short": "Wrk",
            "port": 3030,
            "dir": "/home/user/.local/share/screenpipe/work",
            "dir_short": "~/.local/share/screenpipe/work",
            "exists": True,
            "size_bytes": 1288490188,
            "size_human": "1.2G",
            "selected": active == "work",
            "recording": False,
            "unit_active": False,
            "health": False,
            "agent_share": False,
            "agent": {"share": False, "label": "Work agent", "note": "Local only."},
            "hermes": {"share": False},
        },
        {
            "id": "client",
            "label": "Client",
            "short": "Cli",
            "port": 3031,
            "dir": "/mnt/storage/screenpipe/client",
            "dir_short": "/mnt/storage/screenpipe/client",
            "exists": True,
            "size_bytes": 482344960,
            "size_human": "460M",
            "selected": active == "client",
            "recording": recording and active == "client",
            "unit_active": recording and active == "client",
            "health": recording and active == "client",
            "agent_share": True,
            "agent": {
                "share": True,
                "label": "Client agent",
                "api_url": "http://127.0.0.1:3031",
                "note": "Opt-in summaries when you ask.",
            },
            "hermes": {"share": True, "label": "Client agent"},
        },
        {
            "id": "personal",
            "label": "Personal",
            "short": "Me",
            "port": 3032,
            "dir": "/home/user/.local/share/screenpipe/personal",
            "dir_short": "~/.local/share/screenpipe/personal",
            "exists": True,
            "size_bytes": 89128960,
            "size_human": "85M",
            "selected": active == "personal",
            "recording": False,
            "unit_active": paused,
            "health": paused,
            "agent_share": False,
            "agent": {"share": False, "label": "Personal", "note": "Never shared."},
            "hermes": {"share": False},
        },
    ]
    active_org = next(o for o in orgs if o["id"] == active)
    agent = active_org["agent"]
    return {
        "ready": True,
        "demo": True,
        "demoView": view,
        "paused": paused,
        "recording": recording,
        "mode": "auto",
        "org": active,
        "desired": active,
        "detected": active,
        "reason": "focus:app:Slack" if recording else "default",
        "label": active_org["label"],
        "short": active_org["short"],
        "port": active_org["port"],
        "dir": active_org["dir"],
        "dir_short": active_org["dir_short"],
        "size_human": active_org["size_human"],
        "api_url": agent.get("api_url") or f"http://127.0.0.1:{active_org['port']}",
        "agent_share": bool(agent.get("share")),
        "hermes_share": bool(agent.get("share")),
        "agent": agent,
        "hermes": agent,
        "override": None,
        "orgs": orgs,
        "hint": "",
    }


def status_json() -> dict:
    view = demo_view()
    if view:
        return demo_payload(view)

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
        if demo_view():
            print(json.dumps(demo_payload(demo_view())))
            return 0
        if len(argv) < 3:
            print(json.dumps({"ok": False, "error": "missing action"}))
            return 1
        sub = argv[2]
        # pick-dir <org>  |  set-dir <org> <path>  |  plain verbs / org ids
        if sub == "pick-dir":
            if len(argv) < 4:
                print(json.dumps({"ok": False, "error": "pick-dir needs org id"}))
                return 1
            r = sp("pick-dir", argv[3])
            out = r.stdout.strip() or "{}"
            try:
                st = json.loads(out)
            except json.JSONDecodeError:
                st = status_json()
            st["ok"] = r.returncode == 0
            print(json.dumps(st))
            return 0 if r.returncode == 0 else 1
        if sub == "set-dir":
            if len(argv) < 5:
                print(json.dumps({"ok": False, "error": "set-dir needs org id and path"}))
                return 1
            r = sp("set-dir", argv[3], argv[4], "--json")
            out = r.stdout.strip() or "{}"
            try:
                st = json.loads(out)
            except json.JSONDecodeError:
                st = status_json()
            st["ok"] = r.returncode == 0
            print(json.dumps(st))
            return 0 if r.returncode == 0 else 1

        r = sp(sub)
        st = status_json()
        st["ok"] = r.returncode == 0
        if r.returncode != 0:
            st["error"] = (r.stderr or r.stdout or "failed").strip()[:300]
        print(json.dumps(st))
        return 0 if r.returncode == 0 else 1

    if action == "demo":
        print(json.dumps(demo_payload(argv[2] if len(argv) > 2 else "default")))
        return 0

    print(json.dumps(status_json()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
