#!/usr/bin/env python3
"""Shared validation utilities for the AI Nix-editing pipeline.

Used by ai-issue-handler.yml, ai-issue-autofix.yml, and ai-issue-feedback.yml.
This file must always be checked out from `main` (never from an AI-controlled
branch) so the validation logic itself can never be weakened by the code it
is validating. See AGENTS.md for the full security rationale.

Design note: the path allow-list below is NOT a capability sandbox. A file
placed under modules/ai/** can still set arbitrary NixOS options (that is the
whole point of letting the AI write real Nix code instead of only package
names). The allow-list only constrains *where* generated code lives, so a
human reviewer always knows which files to read. The content scan further
down is advisory only — it is trivially bypassed by nesting attrsets — and
exists to flag a PR for extra-careful review, never to block one. The actual
defense is: every AI-generated PR must be read in full by a human before
merge.
"""
import argparse
import json
import os
import re
import subprocess
import sys

# --- path allow-list --------------------------------------------------------

ALLOWED_PATH_PATTERN = r"(modules/ai|home/ai|tests/ai)/[A-Za-z0-9_-]+\.(nix|kdl|toml|json|conf)"
_ALLOWED_PATH_RE = re.compile(ALLOWED_PATH_PATTERN)


def is_allowed_path(path: str) -> bool:
    """True if `path` is inside the AI edit scope and is not a default.nix."""
    if path.rsplit("/", 1)[-1] == "default.nix":
        return False
    return _ALLOWED_PATH_RE.fullmatch(path) is not None


def validate_paths(paths):
    """Return the subset of `paths` that violate the allow-list."""
    return [p for p in paths if not is_allowed_path(p)]


# --- branch name -------------------------------------------------------------

BRANCH_PATTERN = r"ai/issue-[0-9]+"
_BRANCH_RE = re.compile(BRANCH_PATTERN)


def is_allowed_branch(branch: str) -> bool:
    return _BRANCH_RE.fullmatch(branch) is not None


# --- untrusted-text sanitization ---------------------------------------------

_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
_UNCLOSED_HTML_COMMENT_RE = re.compile(r"<!--.*\Z", re.DOTALL)
_CONTROL_CHARS_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")


def sanitize_text(text: str, max_len: int = 4000) -> str:
    """Strip HTML comments (incl. unclosed ones) and control chars, then truncate.

    Issue bodies and PR comments are untrusted input. HTML comments are
    stripped because a hidden `<!-- ignore all previous instructions -->`
    is a plausible prompt-injection vector; an unclosed `<!--` is stripped
    from that point to end-of-string rather than left as-is, since a naive
    "closed comment only" regex would leave it untouched.
    """
    text = _HTML_COMMENT_RE.sub("", text)
    text = _UNCLOSED_HTML_COMMENT_RE.sub("", text)
    text = _CONTROL_CHARS_RE.sub("", text)
    return text[:max_len]


# --- advisory content scan ----------------------------------------------------
# Two complementary pattern sets:
#  - "parent attribute" patterns catch the namespace being referenced at all
#    (still matches even if the value itself is a nested attrset).
#  - "leaf key" patterns catch specific dangerous keys even when the parent
#    attribute path is itself nested and so evades the patterns above.
# Neither set can catch a fully-nested form like `systemd = { services = {...}; };`
# where both the parent and the leaf are indirect — that is the known,
# accepted limitation. This scan never blocks a PR; it only adds an
# informational label so a human reviewer knows to look closer.

_PARENT_ATTR_PATTERNS = [
    r"systemd\.(services|user\.services|timers)\b",
    r"security\.(sudo|wrappers|pam)\b",
    r"system\.activationScripts",
    r"users\.users\b",
    r"services\.openssh\b",
    r"nix\.settings\b|nix\.extraOptions",
    r"nixpkgs\.overlays",
    r"environment\.etc\b",
    r"networking\.firewall\b",
    r"services\.udev\b",
    r"security\.polkit",
    r"boot\.\w+",
    r"fileSystems\b",
    r"home\.file\b",
    r"xdg\.configFile\b",
]

_LEAF_KEY_PATTERNS = [
    r'"?\b(hashedPassword|initialPassword|password|authorizedKeys|extraGroups|'
    r'substituters|trusted-public-keys|trusted-users|extraRules|extraCommands|'
    r'allowedTCPPorts|allowedUDPPorts)\b"?\s*=',
    r'"?\b\w*([Ii]nit|[Ee]xtra)\w*\b"?\s*=',
]

_MISC_PATTERNS = [
    r"\.\./",
    r"builtins\.(fetchurl|fetchTarball|fetchGit)|(?<![\w.])fetchTarball\b|(?<![\w.])fetchGit\b",
    r"(?<![\w.])import\s+\(?(https?:|<)",
    r"lib\.mkForce|lib\.mkOverride",
    r"home\.activation",
]

_ALL_SCAN_PATTERNS = [
    (pattern, "parent-attribute") for pattern in _PARENT_ATTR_PATTERNS
] + [
    (pattern, "leaf-key") for pattern in _LEAF_KEY_PATTERNS
] + [
    (pattern, "misc") for pattern in _MISC_PATTERNS
]
_COMPILED_SCAN_PATTERNS = [(re.compile(p), kind) for p, kind in _ALL_SCAN_PATTERNS]


def scan_dangerous_content(text: str):
    """Return a sorted list of distinct matched pattern strings (advisory only)."""
    hits = set()
    for compiled, _kind in _COMPILED_SCAN_PATTERNS:
        if compiled.search(text):
            hits.add(compiled.pattern)
    return sorted(hits)


# --- diff parsing (final allow-list re-check) --------------------------------
#
# Replaces the old "AI-declared file list == staged diff" comparison. The
# agent loop (glm_agent.py) already enforces is_allowed_path() at write/delete
# time, but this is the last line of defense: it re-derives the actual
# changed paths from git itself and re-checks every one of them. Callers must
# invoke `git diff` with `--no-renames` (a rename collapses a write+delete
# pair into a single `Rxxx\0old\0new\0` record, which would otherwise hide
# the write's destination path from a naive 2-field parser). This parser
# still understands the 3-field rename/copy form so that if a caller forgets
# `--no-renames`, the violation is caught here instead of silently bypassing
# the check.

_RENAME_OR_COPY_STATUS_RE = re.compile(r"^[RC]")


def parse_diff_name_status(output: str):
    """Parse `git diff --name-status -z` output into (status, paths) tuples.

    `paths` is a 1-tuple for ordinary A/M/D records and a 2-tuple
    `(old_path, new_path)` for R/C (rename/copy) records, which carry an
    extra path field even under `-z`.
    """
    fields = output.split("\0")
    if fields and fields[-1] == "":
        fields.pop()  # trailing NUL produces an empty final field
    entries = []
    i = 0
    while i < len(fields):
        status = fields[i]
        i += 1
        if _RENAME_OR_COPY_STATUS_RE.match(status):
            if i + 1 >= len(fields):
                raise ValueError(
                    f"truncated name-status record: status {status!r} is missing its old/new path pair"
                )
            old_path, new_path = fields[i], fields[i + 1]
            i += 2
            entries.append((status, (old_path, new_path)))
        else:
            if i >= len(fields):
                raise ValueError(f"truncated name-status record: status {status!r} is missing its path")
            path = fields[i]
            i += 1
            entries.append((status, (path,)))
    return entries


def filter_allowed_paths(entries):
    """Return every path across all diff `entries` that fails is_allowed_path().

    Checks all paths of every record (both old and new path for a
    rename/copy record), so a disallowed destination can never hide behind
    an allowed source path or vice versa.
    """
    return [
        path
        for _status, paths in entries
        for path in paths
        if not is_allowed_path(path)
    ]


def changed_paths_by_status(entries, statuses):
    """Return the single path of each non-rename `entries` record whose status
    starts with one of `statuses` (e.g. `("A", "M")` to exclude deletions)."""
    return [
        paths[0]
        for status, paths in entries
        if len(paths) == 1 and status[:1] in statuses
    ]


# --- gh-backed dispatch-input validation (used by ai-issue-autofix.yml) -----


def _gh_json(args):
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        print(f"::error::gh {' '.join(args)} failed: {result.stderr.strip()}")
        sys.exit(1)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        print(f"::error::gh {' '.join(args)} returned non-JSON output: {result.stdout!r}")
        sys.exit(1)


def validate_dispatch(branch: str, run_id: str):
    """Validate a workflow_dispatch `branch`/`run_id` pair before touching either.

    Must be called before the caller checks out `branch` — this function only
    talks to the GitHub API, so a malicious `branch` value can be safely
    rejected without ever fetching it.
    """
    if not is_allowed_branch(branch):
        print(f"::error::branch '{branch}' does not match ^{BRANCH_PATTERN}$. Refusing.")
        sys.exit(1)

    repo = os.environ.get("GH_REPO", "")
    owner = repo.split("/", 1)[0] if "/" in repo else ""
    if not owner:
        print("::error::GH_REPO is not set to '<owner>/<repo>'. Refusing.")
        sys.exit(1)

    # REST (not `gh pr list --json author`, whose GraphQL-backed author object's
    # exact field shape for bot-authored PRs was never verified against this repo
    # and is not worth guessing at): confirmed directly against this repo that
    # GitHub-Actions-authored PRs have user.login == "github-actions[bot]" and
    # user.type == "Bot".
    # `gh api` defaults to POST (not GET) as soon as any -f/-F field is given,
    # so --method GET must be explicit here or this silently hits the "create a
    # pull request" endpoint instead of "list pull requests".
    prs = _gh_json(
        [
            "api",
            "--method",
            "GET",
            f"repos/{repo}/pulls",
            "-f",
            f"head={owner}:{branch}",
            "-f",
            "state=all",
        ]
    )
    matching = [
        pr
        for pr in prs
        if pr.get("head", {}).get("repo", {}).get("full_name") == repo
        and pr.get("user", {}).get("login") == "github-actions[bot]"
        and pr.get("user", {}).get("type") == "Bot"
    ]
    if not matching:
        print(
            f"::error::no same-repo PR authored by github-actions[bot] found "
            f"for head branch '{branch}'. Refusing."
        )
        sys.exit(1)

    run = _gh_json(
        ["run", "view", run_id, "--json", "headBranch,workflowName,conclusion"]
    )
    if run.get("headBranch") != branch:
        print(
            f"::error::run {run_id} headBranch is '{run.get('headBranch')}', "
            f"expected '{branch}'. Refusing."
        )
        sys.exit(1)
    if run.get("workflowName") != "check-light":
        print(
            f"::error::run {run_id} workflowName is '{run.get('workflowName')}', "
            f"expected 'check-light'. Refusing."
        )
        sys.exit(1)
    if run.get("conclusion") != "failure":
        print(
            f"::error::run {run_id} conclusion is '{run.get('conclusion')}', "
            f"expected 'failure'. Refusing."
        )
        sys.exit(1)

    print(f"validate-dispatch OK: branch={branch} run_id={run_id}")


# --- CLI -----------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_paths = sub.add_parser("check-paths", help="Validate changed file paths against the allow-list")
    p_paths.add_argument("paths", nargs="*")

    p_scan = sub.add_parser("scan-content", help="Advisory dangerous-construct scan over stdin")

    p_dispatch = sub.add_parser("validate-dispatch", help="Validate workflow_dispatch branch/run_id inputs")
    p_dispatch.add_argument("--branch", required=True)
    p_dispatch.add_argument("--run-id", required=True)

    sub.add_parser(
        "check-diff",
        help=(
            "Read `git diff --cached --no-renames -z --name-status` from stdin, "
            "re-validate every changed path against the allow-list, and print "
            "the added/modified paths (one per line) for downstream checks"
        ),
    )

    args = parser.parse_args()

    if args.command == "check-paths":
        violations = validate_paths(args.paths)
        if violations:
            print(f"::error::paths outside the AI edit scope: {violations}")
            sys.exit(1)
        print(f"check-paths OK: {len(args.paths)} path(s) validated")

    elif args.command == "scan-content":
        text = sys.stdin.read()
        hits = scan_dangerous_content(text)
        print(json.dumps(hits))

    elif args.command == "validate-dispatch":
        validate_dispatch(args.branch, args.run_id)

    elif args.command == "check-diff":
        try:
            entries = parse_diff_name_status(sys.stdin.read())
        except ValueError as error:
            print(f"::error::malformed diff input: {error}", file=sys.stderr)
            sys.exit(1)
        if not entries:
            print("::error::変更がありませんでした。中断します。", file=sys.stderr)
            sys.exit(1)
        renames = [(status, paths) for status, paths in entries if len(paths) == 2]
        if renames:
            print(
                f"::error::rename/copy records present — caller must pass --no-renames (got {renames})",
                file=sys.stderr,
            )
            sys.exit(1)
        violations = filter_allowed_paths(entries)
        if violations:
            print(f"::error::paths outside the AI edit scope: {violations}", file=sys.stderr)
            sys.exit(1)
        print(f"check-diff OK: {len(entries)} entrie(s) validated", file=sys.stderr)
        for path in changed_paths_by_status(entries, ("A", "M")):
            print(path)


if __name__ == "__main__":
    main()
