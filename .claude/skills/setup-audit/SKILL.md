---
name: setup-audit
description: Bootstrap a new audit engagement workspace — bare-clone the client repo and create the standard worktree layout (ManualAudit, Report, Main, Solace, Grimoire, AuditFixes, MITIGATION_REVIEW). Use when the user says "setup audit", "set up a new audit", "new engagement", "bootstrap the audit repo", "/setup-audit", or gives a repo URL and wants the audit workspace created.
argument-hint: <repo-url> [engagement-dir]
---

# Setup Audit

Creates an audit workspace by running `setup-audit.sh`. The script is the source of truth for the layout. Do not reimplement its steps by hand; run it.

Script: `/Users/stalinmacias/Documents/0xStalin/Audits/Tools/automation-tooling-auditor-workflow/audit_setup/setup-audit.sh`
(The same script is installed on PATH as `setup-audit`. Prefer the repo path so the latest version runs.)

## Inputs

- **Repo URL** (required): the audit repo to clone, e.g. `git@github.com:Cyfrin/audit-2026-10-protocol.git`. If the user did not give one, ask for it.
- **Engagement directory** (optional): where to create the workspace. If not given, use the current working directory.

## Steps

### 1. Pre-flight checks

Run these before the script. The script uses `set -e` and stops halfway on failure, so a failed run leaves a partial workspace.

1. **Target directory is fresh.** If the engagement directory exists, it must not contain `.bare`, `.git`, or any of the worktree folders (`ManualAudit`, `Report`, `Main`, `Solace`, `Grimoire`, `AuditFixes`, `MITIGATION_REVIEW`). If it does, stop and tell the user what you found. Do not delete anything.
   If the directory does not exist, create it with `mkdir -p`.
2. **Remote is reachable and has the required branches.** Run:
   ```bash
   git ls-remote --heads <repo-url> main report audit/Stalin
   ```
   All three branches must exist. They are the bases for the worktrees. If any are missing, stop and list the missing ones. The user may need to create them on the remote first.
3. **New branches do not exist already.** The script creates `solace`, `grimoire`, `audit-fixes`, and `mitigation-review` with `-b`, which fails if they already exist on the remote:
   ```bash
   git ls-remote --heads <repo-url> solace grimoire audit-fixes mitigation-review
   ```
   If any exist, stop and tell the user. The script would fail at that worktree.

### 2. Run the script

From inside the engagement directory:
```bash
cd <engagement-dir> && /Users/stalinmacias/Documents/0xStalin/Audits/Tools/automation-tooling-auditor-workflow/audit_setup/setup-audit.sh <repo-url>
```

If it fails, report the exact error and which step it stopped at (the `→` lines show progress). Do not try to clean up or re-run automatically. Show the user the partial state (`ls -a`, `git worktree list`) and ask how to proceed.

### 3. Report

Show the `git worktree list` output and summarize:

| Worktree | Branch |
|----------|--------|
| `ManualAudit/` | `audit/Stalin` |
| `Report/` | `report` |
| `Main/` | `main` |
| `Solace/` | `solace` (new, from `report`) |
| `Grimoire/` | `grimoire` (new, from `audit/Stalin`) |
| `AuditFixes/` | `audit-fixes` (new, from `main`) |
| `MITIGATION_REVIEW/` | `mitigation-review` (new, from `audit-fixes`) |

The new branches exist only locally. Do not push them unless the user asks.

Then mention the next steps, in one line each:
- `/grimoire:summon` inside `Grimoire/` to start the Grimoire context.
- When client fixes come in: `/pull-fixes <client-repo-url> <fix-commit-hash>` inside `AuditFixes/`. It also merges them into `MITIGATION_REVIEW/`, where the review is done.
