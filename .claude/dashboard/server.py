#!/usr/bin/env python3
"""
WebsiteOS — a live status board for the parallel git-worktree agent-dispatch
pattern this project uses (see docs/ARCHITECTURE.md #13).

The panel title is "WebsiteOS — <Project>", where <Project> is derived from the
repo directory name at runtime (see detect_project_name), so the same panel
drops into another project without a rename. A "session" is whichever Claude
Code window is coordinating (stored as a captain heartbeat file); an "agent" is
a background worker it dispatched into its own isolated git worktree — the code
below still uses the older captain/soldado field names internally, the UI shows
plain language. This server computes fresh data from git + the filesystem on
EVERY request to /api/status — nothing here is a cached snapshot.

Zero third-party dependencies on purpose: stdlib http.server + subprocess only,
matching this project's "no build step" convention.

Usage:
    python3 server.py [port]        # default port 8765

This is internal ops tooling for the agent-orchestration workflow itself. It
is not part of the Hikari Studio site and reads the repo read-only, with one
narrow exception: it appends one JSONL line to its own `history.jsonl` (next
to this file, gitignored) whenever a soldado worktree that was present in a
previous poll has disappeared. It never writes to git or to any tracked file.
"""

import http.server
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit, parse_qs

DASHBOARD_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_PATH = os.path.join(DASHBOARD_DIR, "history.jsonl")
DEFAULT_PORT = 8765
GIT_TIMEOUT_SECS = 5
HISTORY_LIMIT = 20
SERVER_STARTED_AT = time.time()

# A captain (an orchestrating Claude Code session) is considered "active" if
# its heartbeat file's mtime is at least this fresh. This is a real detection
# limit, not a stylistic choice: a captain session that hasn't dispatched
# anything recently and hasn't touched its heartbeat file leaves no trace at
# all, so this single threshold is the entire basis for "N capitanes
# activos" — see .agent-state/captains/<id>.md's own "How to read freshness"
# note (the file's mtime is the signal, not the text inside it).
CAPTAIN_HEARTBEAT_STALE_AFTER_SECS = 20 * 60  # 20 minutes

# Bounds for the per-soldado "most recently modified file" scan (a real
# live-activity signal, not just a lock flag echoing possibly-stale state).
# Kept cheap with a hard file-count cap + wall-clock budget rather than
# shelling out to `find -printf`, since BSD find (stock macOS) and GNU find
# don't agree on that flag — a plain os.walk works identically everywhere
# and is just as easy to bound.
ACTIVITY_SCAN_MAX_FILES = 20000
ACTIVITY_SCAN_TIME_BUDGET_SECS = 1.5

AGENT_BRANCH_RE = re.compile(r"^worktree-agent-([0-9a-f]+)$")
PID_RE = re.compile(r"pid (\d+)")
CLAIM_FIELD_RE = re.compile(r"\*\*([^*:]+):\*\*\s*(.+)")

# Trailing words in a repo directory name that describe the *kind* of repo
# rather than the project, dropped when deriving a display name so
# "hikari-site" reads as "Hikari". Only dropped when something is left over.
PROJECT_NAME_NOISE = {"site", "website", "web", "www", "app", "repo", "project", "demo", "src"}


# ---------------------------------------------------------------------------
# Project identity — derived, never hardcoded, so this panel is portable
# ---------------------------------------------------------------------------

def detect_project_name(repo_root):
    """Display name for this project, in priority order:
      1. $WEBSITEOS_PROJECT
      2. a `project-name.txt` sitting next to this file
      3. the repo directory name, de-noised and title-cased
    Dropping into a different repo therefore needs no edit here."""
    override = os.environ.get("WEBSITEOS_PROJECT", "").strip()
    if override:
        return override

    cfg = os.path.join(DASHBOARD_DIR, "project-name.txt")
    if os.path.isfile(cfg):
        try:
            with open(cfg, "r", encoding="utf-8") as f:
                value = f.read().strip()
            if value:
                return value
        except OSError:
            pass

    base = os.path.basename(os.path.normpath(repo_root or "")) or "Proyecto"
    tokens = [t for t in re.split(r"[-_\s.]+", base) if t]
    if len(tokens) > 1 and tokens[-1].lower() in PROJECT_NAME_NOISE:
        tokens = tokens[:-1]
    if not tokens:
        return base
    return " ".join(t[:1].upper() + t[1:] for t in tokens)


# ---------------------------------------------------------------------------
# git plumbing
# ---------------------------------------------------------------------------

def run_git(cwd, args):
    """Run `git -C cwd <args>`, return (stdout_stripped, returncode)."""
    try:
        result = subprocess.run(
            ["git", "-C", cwd] + args,
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT_SECS,
        )
        return result.stdout.strip(), result.returncode
    except Exception as exc:  # noqa: BLE001 - surface any failure as empty/1
        return "", 1


def find_repo_root():
    """The first row of `git worktree list` is always the primary checkout,
    regardless of which worktree we run the command from (all worktrees
    share the same .git), so this needs no hardcoded path."""
    out, code = run_git(DASHBOARD_DIR, ["worktree", "list", "--porcelain"])
    if code == 0 and out:
        for line in out.splitlines():
            if line.startswith("worktree "):
                return line[len("worktree "):].strip()
    # Fallback: this file's own toplevel.
    top, _ = run_git(DASHBOARD_DIR, ["rev-parse", "--show-toplevel"])
    return top or DASHBOARD_DIR


def parse_worktrees(porcelain_output):
    """Parse `git worktree list --porcelain` into a list of dicts."""
    worktrees = []
    current = {}

    def flush():
        if current:
            worktrees.append(dict(current))

    for line in porcelain_output.splitlines():
        if line == "":
            flush()
            current.clear()
            continue
        if line.startswith("worktree "):
            current["path"] = line[len("worktree "):]
        elif line.startswith("HEAD "):
            current["head"] = line[len("HEAD "):]
        elif line.startswith("branch "):
            ref = line[len("branch "):]
            current["branch"] = ref[len("refs/heads/"):] if ref.startswith("refs/heads/") else ref
            current["detached"] = False
        elif line == "detached":
            current["branch"] = None
            current["detached"] = True
        elif line == "bare":
            current["bare"] = True
        elif line == "locked" or line.startswith("locked "):
            current["locked"] = True
            reason = line[len("locked"):].strip()
            current["lock_reason"] = reason or None
        elif line == "prunable" or line.startswith("prunable "):
            current["prunable"] = True
            reason = line[len("prunable"):].strip()
            current["prunable_reason"] = reason or None

    flush()
    return worktrees


def pid_alive(pid):
    """Cheap liveness check for a pid embedded in a worktree lock reason."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # exists, just not ours to signal
    except Exception:  # noqa: BLE001
        return None  # unknown, don't guess
    return True


def find_worktree_meta_dirs(repo_root):
    """Map each worktree's working-tree path -> its `.git/worktrees/<name>`
    metadata dir, by reading the `gitdir` pointer file each metadata dir
    contains. Pure filesystem walk, no extra git subprocess calls — used to
    read the `locked` file's mtime (an honest "locked since" timestamp;
    `git worktree list --porcelain` reports lock *reason* but not *when*)."""
    base = os.path.join(repo_root, ".git", "worktrees")
    mapping = {}
    if not os.path.isdir(base):
        return mapping
    try:
        names = os.listdir(base)
    except OSError:
        return mapping
    for name in names:
        meta_dir = os.path.join(base, name)
        gitdir_file = os.path.join(meta_dir, "gitdir")
        try:
            with open(gitdir_file, "r", encoding="utf-8") as f:
                pointer = f.read().strip()
        except OSError:
            continue
        wt_path = pointer[:-len("/.git")] if pointer.endswith("/.git") else os.path.dirname(pointer)
        mapping[os.path.normpath(wt_path)] = meta_dir
    return mapping


def lock_timestamp(entry_path, meta_dirs):
    """Return (iso_string, seconds_ago) for when this worktree was locked,
    read from the mtime of its `.git/worktrees/<name>/locked` file. None if
    unlocked or the file can't be found — never guessed."""
    meta_dir = meta_dirs.get(os.path.normpath(entry_path))
    if not meta_dir:
        return None, None
    lock_file = os.path.join(meta_dir, "locked")
    try:
        mtime = os.path.getmtime(lock_file)
    except OSError:
        return None, None
    iso = time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(mtime))
    return iso, max(0.0, time.time() - mtime)


def read_claim(repo_root, branch):
    """Read `.agent-state/claims/agent-<hash>.md` for this soldado, if the
    orchestrator filed one — the one honest source of an actual task
    description (see docs/ARCHITECTURE.md #13 dispatch pattern). Returns None
    if no claim file exists; never invents a task description otherwise."""
    if not branch:
        return None
    m = AGENT_BRANCH_RE.match(branch)
    if not m:
        return None
    claim_path = os.path.join(repo_root, ".agent-state", "claims", f"agent-{m.group(1)}.md")
    if not os.path.isfile(claim_path):
        return None
    try:
        with open(claim_path, "r", encoding="utf-8") as f:
            raw = f.read()
    except OSError:
        return None
    fields = {}
    for line in raw.splitlines():
        fm = CLAIM_FIELD_RE.search(line)
        if fm:
            fields[fm.group(1).strip().lower()] = fm.group(2).strip()
    return {
        "path": claim_path,
        "raw": raw,
        "task": fields.get("task"),
        "allowed_scope": fields.get("allowed scope"),
        "forbidden": fields.get("forbidden"),
        "filed": fields.get("filed"),
        "confidence": fields.get("confidence"),
        # Optional, backwards-compatible: older claims won't have this field
        # and fields.get() just returns None for them — those soldados fall
        # into the "capitán desconocido / sin declarar" bucket in the UI
        # rather than being hidden or guessed at.
        "captain": fields.get("captain"),
    }


def read_captains(repo_root):
    """Read every `.agent-state/captains/<id>.md` heartbeat file. One file
    per captain (an orchestrating Claude Code session); the filename IS the
    captain's id. Freshness is judged purely by the file's mtime (per the
    convention documented inside the files themselves) — never by parsing a
    timestamp out of the text, which could go stale without the file being
    touched. Returns a list sorted most-recently-active first."""
    captains_dir = os.path.join(repo_root, ".agent-state", "captains")
    result = []
    if not os.path.isdir(captains_dir):
        return result
    try:
        names = sorted(os.listdir(captains_dir))
    except OSError:
        return result

    now = time.time()
    for name in names:
        if not name.endswith(".md"):
            continue
        path = os.path.join(captains_dir, name)
        if not os.path.isfile(path):
            continue
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue

        label = None
        try:
            with open(path, "r", encoding="utf-8") as f:
                raw = f.read()
        except OSError:
            raw = ""
        for line in raw.splitlines():
            fm = CLAIM_FIELD_RE.search(line)
            if fm and fm.group(1).strip().lower() == "label":
                label = fm.group(2).strip()
                break

        seconds_ago = max(0.0, now - mtime)
        result.append({
            "id": name[:-3],
            "path": path,
            "label": label,
            "heartbeat_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(mtime)),
            "heartbeat_seconds_ago": seconds_ago,
            "active": seconds_ago <= CAPTAIN_HEARTBEAT_STALE_AFTER_SECS,
        })

    result.sort(key=lambda c: c["heartbeat_seconds_ago"])
    return result


def find_most_recent_activity(root_dir):
    """Bounded scan for the most recently modified file under root_dir
    (excluding .git/), used as an honest "is this soldado actually still
    typing" signal — a locked flag alone can't distinguish a live agent from
    one that crashed mid-task. Stops early past ACTIVITY_SCAN_MAX_FILES files
    or ACTIVITY_SCAN_TIME_BUDGET_SECS of wall-clock time and returns the best
    answer found so far (truncated=True in that case, so the caller/UI can
    stay honest about it being a partial scan rather than a guaranteed-exact
    one)."""
    start = time.monotonic()
    best_mtime = None
    best_path = None
    scanned = 0
    truncated = False
    try:
        for dirpath, dirnames, filenames in os.walk(root_dir):
            dirnames[:] = [d for d in dirnames if d != ".git"]
            for fn in filenames:
                scanned += 1
                if scanned > ACTIVITY_SCAN_MAX_FILES or (time.monotonic() - start) > ACTIVITY_SCAN_TIME_BUDGET_SECS:
                    truncated = True
                    break
                fp = os.path.join(dirpath, fn)
                try:
                    m = os.path.getmtime(fp)
                except OSError:
                    continue
                if best_mtime is None or m > best_mtime:
                    best_mtime = m
                    best_path = fp
            if truncated:
                break
    except OSError:
        return None, None, False
    return best_mtime, best_path, truncated


def classify_worktree(wt, repo_root, main_branch_sha):
    """Decide a soldado's operational state.

    States:
      hq            - the primary checkout (the General's own desk, not a soldado)
      active        - locked, presumed still working
      stale_lock    - locked, but the pid in the lock reason is dead (orphaned lock,
                       needs a human to `git worktree unlock` / investigate)
      needs_review  - unlocked, but carries commits not reachable from main
                       (finished-looking but has unmerged local work sitting there)
      idle          - unlocked, nothing pending
    """
    is_hq = os.path.normpath(wt.get("path", "")) == os.path.normpath(repo_root)
    if is_hq:
        return "hq", None

    if wt.get("locked"):
        pid_match = PID_RE.search(wt.get("lock_reason") or "")
        if pid_match:
            alive = pid_alive(int(pid_match.group(1)))
            if alive is False:
                return "stale_lock", int(pid_match.group(1))
        return "active", None

    ahead = wt.get("ahead", 0)
    if ahead and ahead > 0:
        return "needs_review", None
    return "idle", None


# ---------------------------------------------------------------------------
# KANBAN.md — parsed into sections when it has clear "## " headers
# ---------------------------------------------------------------------------

KANBAN_BULLET_RE = re.compile(r"^(\s*)(?:[-*]|(\d+)\.)\s+(.*)$")
KANBAN_LEAD_RE = re.compile(r"^\*\*(.+?)\*\*[.:]?\s*(.*)$", re.S)
KANBAN_DONE_RE = re.compile(r"^(?:~~|\[x\]\s|- \[x\]\s)", re.I)
KANBAN_DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")


def classify_kanban_section(heading):
    """Map a KANBAN section heading onto a board column. Keyword-based on
    purpose so the panel works against another project's KANBAN.md without
    edits; anything unrecognised falls through to `todo` rather than being
    dropped, and `reference` sections are kept out of the board entirely
    (they hold links, not work)."""
    h = (heading or "").lower()
    if re.search(r"cross-?ref|referenc|enlaces|links", h):
        return "reference"
    if re.search(r"block|bloque|waiting|espera|on hold", h):
        return "blocked"
    if re.search(r"human|decis|necesita|manual|input", h):
        return "blocked"
    if re.search(r"done|listo|hecho|complet|shipped|cerrad|archiv", h):
        return "done"
    if re.search(r"progress|curso|doing|wip|en marcha", h):
        return "doing"
    return "todo"


def parse_kanban_items(body):
    """Split a section body into its TOP-LEVEL list items (indent 0). Wrapped
    continuation lines are rejoined into one paragraph; nested bullets are kept
    separately as `sub` so a multi-part item still shows its parts. Returns []
    for prose-only sections — the caller then keeps showing the prose."""
    groups = []
    current = None
    for line in body.splitlines():
        m = KANBAN_BULLET_RE.match(line)
        if m and not m.group(1):
            if current:
                groups.append(current)
            current = {"order": int(m.group(2)) if m.group(2) else None,
                       "head": [m.group(3).strip()], "sub": []}
            continue
        if current is None:
            continue
        stripped = line.strip()
        if not stripped:
            continue
        nested = KANBAN_BULLET_RE.match(line)
        if nested and nested.group(1):
            current["sub"].append(nested.group(3).strip())
        elif current["sub"]:
            current["sub"][-1] = (current["sub"][-1] + " " + stripped).strip()
        else:
            current["head"].append(stripped)
    if current:
        groups.append(current)

    items = []
    for g in groups:
        text = " ".join(g["head"]).strip()
        if not text:
            continue
        done = bool(KANBAN_DONE_RE.match(text))
        lead = KANBAN_LEAD_RE.match(text)
        if lead:
            title, rest = lead.group(1).strip(), lead.group(2).strip()
        else:
            title, rest = None, text
        date_match = KANBAN_DATE_RE.search(text)
        items.append({
            "raw": text,
            "title": title,
            "body": rest,
            "sub": g["sub"],
            "order": g["order"],
            "done": done,
            "date": date_match.group(0) if date_match else None,
        })
    return items


def parse_kanban_sections(raw):
    lines = raw.splitlines()
    title = None
    intro_lines = []
    sections = []
    current = None

    for line in lines:
        h1 = re.match(r"^#\s+(.*)", line)
        h2 = re.match(r"^##\s+(.*)", line)
        if h1 and title is None and current is None and not sections:
            title = h1.group(1).strip()
            continue
        if h2:
            if current is not None:
                sections.append(current)
            current = {"heading": h2.group(1).strip(), "lines": []}
            continue
        if current is None:
            intro_lines.append(line)
        else:
            current["lines"].append(line)

    if current is not None:
        sections.append(current)

    out_sections = []
    for s in sections:
        body = "\n".join(s["lines"]).strip()
        out_sections.append({
            "heading": s["heading"],
            "body": body,
            "column": classify_kanban_section(s["heading"]),
            "items": parse_kanban_items(body),
        })

    return {
        "title": title,
        "intro": "\n".join(intro_lines).strip(),
        "sections": out_sections,
    }


def read_kanban(repo_root):
    path = os.path.join(repo_root, "docs", "KANBAN.md")
    if not os.path.isfile(path):
        return {"exists": False, "path": path}
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
    except OSError as exc:
        return {"exists": False, "path": path, "error": str(exc)}
    parsed = parse_kanban_sections(raw)
    return {
        "exists": True,
        "path": path,
        "raw": raw,
        "title": parsed["title"],
        "intro": parsed["intro"],
        "sections": parsed["sections"],
        "has_sections": len(parsed["sections"]) > 0,
    }


# ---------------------------------------------------------------------------
# Run history — a lightweight local log of soldado lifecycles, so patterns
# ("does agent X always end up needs_review?") can emerge over time. A flat
# JSONL file, nothing fancier: in-memory tracking of "what did we see last
# poll" resets if the dashboard process restarts, which is an accepted
# trade-off for a local dev aid, not a system of record.
# ---------------------------------------------------------------------------

_tracked_lock = threading.Lock()
_tracked_worktrees = {}  # key (branch or path) -> {branch, path, first_seen, last_seen, state}


def _worktree_key(entry):
    return entry.get("branch") or entry.get("path")


def _append_history(record):
    try:
        with open(HISTORY_PATH, "a", encoding="utf-8") as f:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError:
        pass  # best-effort logging only; never break the live dashboard over it


def update_history_tracking(worktrees):
    """Diff this poll's soldado set against the last one. Anything new gets
    a first_seen/last_seen record; anything that vanished (finished, was
    cleaned up, or its worktree was pruned) gets one line appended to
    history.jsonl and is dropped from the in-memory set."""
    now = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    with _tracked_lock:
        current_keys = set()
        for w in worktrees:
            if w["state"] == "hq":
                continue
            key = _worktree_key(w)
            if not key:
                continue
            current_keys.add(key)
            prior = _tracked_worktrees.get(key)
            if prior is None:
                _tracked_worktrees[key] = {
                    "branch": w.get("branch"),
                    "path": w.get("path"),
                    "first_seen": now,
                    "last_seen": now,
                    "state": w["state"],
                }
            else:
                prior["last_seen"] = now
                prior["state"] = w["state"]

        gone_keys = [k for k in _tracked_worktrees if k not in current_keys]
        for key in gone_keys:
            record = _tracked_worktrees.pop(key)
            _append_history({
                "branch": record.get("branch"),
                "path": record.get("path"),
                "first_seen": record.get("first_seen"),
                "last_seen": record.get("last_seen"),
                "final_state": record.get("state"),
                "logged_at": now,
            })


def read_history(limit=HISTORY_LIMIT):
    if not os.path.isfile(HISTORY_PATH):
        return []
    try:
        with open(HISTORY_PATH, "r", encoding="utf-8") as f:
            lines = [ln for ln in f.read().splitlines() if ln.strip()]
    except OSError:
        return []
    out = []
    for ln in lines[-limit:]:
        try:
            out.append(json.loads(ln))
        except ValueError:
            continue
    out.reverse()  # most recent first
    return out


# ---------------------------------------------------------------------------
# Build the full, fresh payload
# ---------------------------------------------------------------------------

def build_status():
    repo_root = find_repo_root()

    wt_out, wt_code = run_git(repo_root, ["worktree", "list", "--porcelain"])
    raw_worktrees = parse_worktrees(wt_out) if wt_code == 0 else []

    main_sha, _ = run_git(repo_root, ["rev-parse", "main"])
    meta_dirs = find_worktree_meta_dirs(repo_root)

    worktrees = []
    for wt in raw_worktrees:
        head = wt.get("head", "")
        wt_path = wt.get("path", "")
        entry = {
            "path": wt_path,
            "branch": wt.get("branch"),
            "detached": bool(wt.get("detached")),
            "head": head,
            "head_short": head[:7] if head else "",
            "locked": bool(wt.get("locked")),
            "lock_reason": wt.get("lock_reason"),
            "prunable": bool(wt.get("prunable")),
        }

        if head:
            subj_out, _ = run_git(repo_root, ["log", "-1", "--format=%s\x1f%cI\x1f%cr", head])
            parts = subj_out.split("\x1f") if subj_out else []
            entry["commit_subject"] = parts[0] if len(parts) > 0 else ""
            entry["commit_date"] = parts[1] if len(parts) > 1 else ""
            entry["commit_relative"] = parts[2] if len(parts) > 2 else ""

            lr_out, lr_code = run_git(repo_root, ["rev-list", "--left-right", "--count", f"main...{head}"])
            if lr_code == 0 and lr_out:
                bits = lr_out.split()
                if len(bits) == 2:
                    entry["behind"] = int(bits[0])
                    entry["ahead"] = int(bits[1])

        branch = entry["branch"]
        entry["naming_conforms"] = bool(branch) and (
            branch == "main" or bool(AGENT_BRANCH_RE.match(branch))
        )

        state, extra = classify_worktree({**wt, "ahead": entry.get("ahead", 0)}, repo_root, main_sha)
        entry["state"] = state
        if state == "stale_lock":
            entry["dead_pid"] = extra

        # Uncommitted local changes in THIS worktree (not just HQ's) — the
        # honest "sin cambios sin commitear" signal per soldado.
        if wt_path and state != "hq":
            wt_status_out, wt_status_code = run_git(wt_path, ["status", "--short"])
            if wt_status_code == 0:
                entry["dirty_count"] = len(wt_status_out.splitlines()) if wt_status_out else 0

        # When it was locked (mtime of the lock file) — real, not guessed.
        if state in ("active", "stale_lock"):
            locked_since, locked_seconds = lock_timestamp(wt_path, meta_dirs)
            entry["locked_since"] = locked_since
            entry["locked_seconds"] = locked_seconds

        # The orchestrator's own claim file for this soldado, if filed —
        # the real "what is it building" description when one exists.
        if state != "hq":
            claim = read_claim(repo_root, branch)
            entry["claim"] = claim
            # Which captain dispatched this soldado, per the claim's optional
            # "Captain:" field. None (no claim, or a claim filed before this
            # field existed) means the UI must group it under an explicit
            # "capitán desconocido / sin declarar" bucket — never hidden,
            # never guessed.
            entry["captain_id"] = (claim or {}).get("captain") or None

        # Real "is this thing actually alive" signal: the most recently
        # modified file in this worktree (bounded scan, .git/ excluded).
        # Only computed for locked soldados (active / stale_lock) — the
        # states where "is it really still moving" is the open question.
        if state in ("active", "stale_lock") and wt_path:
            last_mtime, last_path, truncated = find_most_recent_activity(wt_path)
            entry["last_activity_epoch"] = last_mtime
            entry["last_activity_path"] = (
                os.path.relpath(last_path, wt_path) if last_path else None
            )
            entry["last_activity_scan_truncated"] = truncated

        worktrees.append(entry)

    # Sort: HQ first, then locked/active, then needs_review, then idle.
    state_order = {"hq": 0, "stale_lock": 1, "active": 2, "needs_review": 3, "idle": 4}
    worktrees.sort(key=lambda e: (state_order.get(e["state"], 9), e["path"]))

    # Structured rather than `--oneline` text: the board needs each commit's
    # own timestamp to sort it into the "Listo" feed alongside finished agents.
    recent_out, _ = run_git(
        repo_root, ["log", "-10", "--format=%h\x1f%s\x1f%cI\x1f%cr\x1f%an", "main"]
    )
    recent_commits = []
    for line in (recent_out.splitlines() if recent_out else []):
        bits = line.split("\x1f")
        if not bits or not bits[0]:
            continue
        recent_commits.append({
            "sha": bits[0],
            "subject": bits[1] if len(bits) > 1 else "",
            "date": bits[2] if len(bits) > 2 else "",
            "relative": bits[3] if len(bits) > 3 else "",
            "author": bits[4] if len(bits) > 4 else "",
        })

    status_out, _ = run_git(repo_root, ["status", "--short"])
    git_status = status_out.splitlines() if status_out else []

    kanban = read_kanban(repo_root)

    non_conforming = [w for w in worktrees if w["state"] != "hq" and not w["naming_conforms"]]

    update_history_tracking(worktrees)

    try:
        hostname = socket.gethostname()
    except Exception:  # noqa: BLE001
        hostname = ""

    captains = read_captains(repo_root)
    soldados_working_count = len([w for w in worktrees if w["state"] == "active"])

    return {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "project_name": detect_project_name(repo_root),
        "repo_root": repo_root,
        "dashboard_dir": DASHBOARD_DIR,
        "hostname": hostname,
        "dashboard_started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(SERVER_STARTED_AT)),
        "dashboard_uptime_s": max(0.0, time.time() - SERVER_STARTED_AT),
        "worktrees": worktrees,
        "orchestrator_advisory": {
            "total": len([w for w in worktrees if w["state"] != "hq"]),
            "non_conforming_count": len(non_conforming),
            "non_conforming_branches": [w["branch"] or "(detached)" for w in non_conforming],
        },
        "recent_commits": recent_commits,
        "git_status": git_status,
        "kanban": kanban,
        "history": read_history(),
        "captains": {
            "list": captains,
            "active_count": len([c for c in captains if c["active"]]),
            "total_count": len(captains),
            "heartbeat_stale_after_secs": CAPTAIN_HEARTBEAT_STALE_AFTER_SECS,
        },
        "soldados_working_count": soldados_working_count,
    }


def build_worktree_detail(target_path):
    """Raw git detail for one soldado, on demand (not part of the main
    /api/status poll — kept separate so the frequent poll stays cheap and
    this only runs when a card is actually expanded). `target_path` must be
    one of the paths `git worktree list` currently reports; anything else is
    rejected so this endpoint can't be used to read arbitrary local paths."""
    repo_root = find_repo_root()
    wt_out, wt_code = run_git(repo_root, ["worktree", "list", "--porcelain"])
    raw_worktrees = parse_worktrees(wt_out) if wt_code == 0 else []
    known_paths = {os.path.normpath(w.get("path", "")) for w in raw_worktrees}
    norm_target = os.path.normpath(target_path or "")
    if not norm_target or norm_target not in known_paths:
        return None

    log_out, _ = run_git(norm_target, ["log", "-20", "--oneline"])
    status_out, _ = run_git(norm_target, ["status", "--short"])
    branch_out, _ = run_git(norm_target, ["rev-parse", "--abbrev-ref", "HEAD"])

    return {
        "path": norm_target,
        "branch": branch_out or None,
        "log": log_out.splitlines() if log_out else [],
        "status": status_out.splitlines() if status_out else [],
    }


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------

class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "WebsiteOS/2.0"

    def log_message(self, fmt, *args):
        sys.stderr.write("[dashboard] " + (fmt % args) + "\n")

    def do_GET(self):
        parsed = urlsplit(self.path)
        if parsed.path in ("/", "/index.html"):
            self._serve_file("index.html", "text/html; charset=utf-8")
        elif parsed.path == "/api/status":
            self._serve_status()
        elif parsed.path == "/api/worktree-detail":
            self._serve_worktree_detail(parsed.query)
        else:
            self.send_error(404, "Not found")

    def _serve_file(self, name, content_type):
        path = os.path.join(DASHBOARD_DIR, name)
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError:
            self.send_error(404, "Not found")
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _serve_status(self):
        try:
            payload = build_status()
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
        except Exception as exc:  # noqa: BLE001
            body = json.dumps({"error": str(exc)}).encode("utf-8")
            self.send_response(500)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _serve_worktree_detail(self, query_string):
        params = parse_qs(query_string or "")
        target = (params.get("path") or [""])[0]
        try:
            detail = build_worktree_detail(target)
            if detail is None:
                body = json.dumps({"error": "unknown worktree path"}).encode("utf-8")
                self.send_response(404)
            else:
                body = json.dumps(detail).encode("utf-8")
                self.send_response(200)
        except Exception as exc:  # noqa: BLE001
            body = json.dumps({"error": str(exc)}).encode("utf-8")
            self.send_response(500)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main():
    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass

    server = None
    bound_port = None
    last_err = None
    for candidate in range(port, port + 10):
        try:
            server = http.server.ThreadingHTTPServer(("127.0.0.1", candidate), Handler)
            bound_port = candidate
            break
        except OSError as exc:
            last_err = exc

    if server is None:
        print(f"Could not bind any port in {port}-{port + 9}: {last_err}", file=sys.stderr)
        sys.exit(1)

    url = f"http://localhost:{bound_port}"
    print(f"WebsiteOS — {detect_project_name(find_repo_root())}")
    print(f"  {url}")
    print("  (Ctrl+C to stop)")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nDeteniendo el panel...")
        server.shutdown()


if __name__ == "__main__":
    main()
