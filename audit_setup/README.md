# Audit Setup

Bootstraps an audit workspace by bare-cloning a target repo and creating the standard worktree layout for an engagement.

## Requirements

- `git`
- SSH access to the target repo (or HTTPS)

## Setup

Make the script executable and put it on your PATH (only needed once):
```bash
chmod +x setup-audit.sh
cp setup-audit.sh /usr/local/bin/setup-audit
```

`cp` preserves the executable bit, so no second `chmod` is needed after copying.

## Usage

From any fresh engagement directory:
```bash
mkdir my-engagement && cd my-engagement
setup-audit git@github.com:client/protocol.git
```

### As a Claude Code skill

The `/setup-audit` skill (`.claude/skills/setup-audit/`) runs this script after pre-flight checks (fresh directory, required remote branches exist). To make it available from any engagement directory, symlink it into your user skills from this folder (only needed once):
```bash
ln -s "$PWD/../.claude/skills/setup-audit" ~/.claude/skills/setup-audit
```

Then, in Claude Code: `/setup-audit git@github.com:client/protocol.git`

## What it does

1. Bare-clones the repo into `.bare`
2. Points `.git` at `.bare` so git commands work from the engagement root
3. Fixes the fetch refspec so remote tracking branches behave like a normal clone
4. Creates the following worktrees:

| Worktree | Branch |
|----------|--------|
| `ManualAudit/` | `audit/Stalin` |
| `Report/` | `report` |
| `Main/` | `main` |
| `Solace/` | `solace` (new, branched from `report`) |
| `Grimoire/` | `grimoire` (new, branched from `audit/Stalin`) |
| `AuditFixes/` | `audit-fixes` (new, branched from `main`) — used to pull mitigations from the client's external repo and push them to `origin` |
| `MITIGATION_REVIEW/` | `mitigation-review` (new, branched from `audit-fixes`) — where the mitigation review is done, so `audit-fixes` stays an untouched copy of the client's fixes |

## Pulling mitigations from the client's external repo

Use [`mitigation-review-single`](../mitigation_review/single-repo/README.md) from inside `AuditFixes/`:
```bash
cd AuditFixes/
mitigation-review-single <client_repo_url> <fix_commit_hash>
```

It merges the client's fix commits into `audit-fixes` (keeping their original hashes), verifies them, and pushes to `origin`. A fast-forward isn't possible, because `audit-fixes` carries the audit repo's own commits on top of the client's history.

It then merges `audit-fixes` into `mitigation-review` automatically, so `MITIGATION_REVIEW/` always has the latest fixes. Do the review there, and never commit review work to `audit-fixes`.

For audit repos that hold several client repos in their own folders, see [`mitigation-review-multi`](../mitigation_review/multi-repo/README.md).
