#!/usr/bin/env python3
"""blitz.screenpipe collector — inbox + file-later wrapper around sp-org."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def sp(*args: str) -> subprocess.CompletedProcess[str]:
    bin_path = shutil.which("sp-org") or str(Path.home() / ".local/bin/sp-org")
    return subprocess.run([bin_path, *args], text=True, capture_output=True, check=False)


def demo_view() -> str:
    flag = HERE / "DEMO"
    try:
        if flag.is_file():
            return flag.read_text(encoding="utf-8").strip() or "default"
    except OSError:
        pass
    return ""


def demo_payload(view: str = "default") -> dict:
    in_meeting = view not in ("paused", "idle", "pending")
    pending_only = view == "pending"
    return {
        "ready": True,
        "demo": True,
        "demoView": view,
        "mode": "inbox",
        "paused": view == "paused",
        "recording": view != "paused",
        "in_meeting": in_meeting,
        "notify": in_meeting,
        "label": "Standup" if in_meeting else "Inbox",
        "short": "REC" if in_meeting else "In",
        "reason": "Zoom" if in_meeting else "idle",
        "dir_short": "~/.local/share/screenpipe/inbox",
        "size_human": "180M",
        "port": 3030,
        "pending_count": 1 if pending_only or not in_meeting else 0,
        "active_meeting": {
            "id": 42,
            "app": "Zoom",
            "label": "Weekly standup",
            "open": True,
        }
        if in_meeting
        else None,
        "pending": [
            {
                "id": 41,
                "app": "Slack",
                "label": "Client sync",
                "open": False,
                "filed": False,
                "suggest": "client",
                "suggest_label": "Client",
            }
        ]
        if pending_only or not in_meeting
        else [],
        "orgs": [
            {
                "id": "work",
                "label": "Work",
                "short": "Wrk",
                "dir_short": "~/.local/share/screenpipe/work",
                "size_human": "1.1G",
                "agent_share": False,
            },
            {
                "id": "client",
                "label": "Client",
                "short": "Cli",
                "dir_short": "/mnt/storage/screenpipe/client",
                "size_human": "420M",
                "agent_share": True,
            },
            {
                "id": "personal",
                "label": "Personal",
                "short": "Me",
                "dir_short": "~/.local/share/screenpipe/personal",
                "size_human": "90M",
                "agent_share": False,
            },
        ],
        "destinations": [],
        "hint": "",
    }


def status_json() -> dict:
    if demo_view():
        return demo_payload(demo_view())
    r = sp("status", "--json")
    if r.returncode != 0 or not r.stdout.strip():
        return {
            "ready": False,
            "paused": True,
            "recording": False,
            "mode": "inbox",
            "orgs": [],
            "pending": [],
            "hint": (r.stderr or r.stdout or "sp-org failed")[:200],
        }
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"ready": False, "hint": "bad json", "orgs": [], "pending": []}


def main(argv: list[str]) -> int:
    if len(argv) <= 1 or argv[1] in ("status", "collect"):
        print(json.dumps(status_json()))
        return 0

    if argv[1] == "action":
        if demo_view():
            print(json.dumps(demo_payload(demo_view())))
            return 0
        if len(argv) < 3:
            print(json.dumps({"ok": False, "error": "missing action"}))
            return 1
        sub = argv[2]
        if sub == "file":
            r = sp("file", argv[3], argv[4]) if len(argv) >= 5 else sp("status", "--json")
        elif sub == "pick-dir":
            r = sp("pick-dir", argv[3]) if len(argv) >= 4 else sp("status", "--json")
        elif sub in ("pause", "resume", "ack", "ensure"):
            r = sp(sub)
            if sub != "ack":
                # ensure status json
                st = status_json()
                st["ok"] = r.returncode == 0
                if r.returncode != 0:
                    st["error"] = (r.stderr or r.stdout or "")[:300]
                print(json.dumps(st))
                return 0 if r.returncode == 0 else 1
        else:
            r = sp(sub)

        out = (r.stdout or "").strip()
        try:
            st = json.loads(out) if out.startswith("{") else status_json()
        except json.JSONDecodeError:
            st = status_json()
        st["ok"] = r.returncode == 0
        if r.returncode != 0 and "error" not in st:
            st["error"] = (r.stderr or r.stdout or "failed")[:300]
        print(json.dumps(st))
        return 0 if r.returncode == 0 else 1

    if argv[1] == "demo":
        print(json.dumps(demo_payload(argv[2] if len(argv) > 2 else "default")))
        return 0

    print(json.dumps(status_json()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
