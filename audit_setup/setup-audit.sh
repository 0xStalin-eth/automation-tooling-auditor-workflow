#!/usr/bin/env bash
#
# Audit workspace bootstrap.
# Bare-clones the target repo and lays out the worktrees for the engagement.
#
# Usage:
#   mkdir <engagement-name> && cd $_
#   ./setup-audit.sh <repo-url>
#
# Example:
#   ./setup-audit.sh git@github.com:client/protocol.git

set -euo pipefail

# ── Args ───────────────────────────────────────────────────────────────────────
REPO_URL="${1:?Usage: $0 <repo-url>}"

# ── Bare clone + .git pointer ──────────────────────────────────────────────────
echo "→ Cloning bare repo into .bare"
git clone --bare "$REPO_URL" .bare

echo "→ Pointing .git at .bare"
echo "gitdir: ./.bare" > .git

echo "→ Fixing fetch refspec so remote tracking behaves like a normal clone"
git config --unset-all remote.origin.fetch 2>/dev/null || true
git config --add remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

echo "→ Fetching origin"
git fetch origin

# ── Worktrees ──────────────────────────────────────────────────────────────────
echo "→ Creating worktrees"
git worktree add ManualAudit audit/Stalin
git worktree add Report      report
git worktree add Main        main
git worktree add -b solace   Solace    report
git worktree add -b grimoire Grimoire  audit/Stalin

# ── Summary ────────────────────────────────────────────────────────────────────
echo
echo "✓ Done. Worktrees:"
git worktree list
