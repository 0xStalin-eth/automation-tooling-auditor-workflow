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

## Pulling mitigations from the client's external repo

Use [`mitigation-review-single`](../mitigation_review/single-repo/README.md) from inside `AuditFixes/`:
```bash
cd AuditFixes/
mitigation-review-single <client_repo_url> <fix_commit_hash>
```

It merges the client's fix commits into `audit-fixes` (keeping their original hashes), verifies them, and pushes to `origin`. A fast-forward isn't possible, because `audit-fixes` carries the audit repo's own commits on top of the client's history.

For audit repos that hold several client repos in their own folders, see [`mitigation-review-multi`](../mitigation_review/multi-repo/README.md).
