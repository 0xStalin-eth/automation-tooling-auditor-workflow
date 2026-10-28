---
name: pull-fixes
description: Pull the client's fix commits into the audit-fixes branch (keeping their original hashes), verify them, push audit-fixes to the Cyfrin repo after confirmation, and sync the local MITIGATION_REVIEW workspace. Only runs from a worktree with the audit-fixes branch checked out (the AuditFixes/ worktree). Use when the user says "pull fixes", "pull the client's fixes", "new fix round", "fixes are in", "bring in the mitigations", "update audit-fixes", "/pull-fixes", or gives a client repo URL and fix commit hash during a mitigation review.
argument-hint: <client-repo-url> <fix-commit-hash>
---

# Pull Fixes

Brings a round of client fixes into a **single-repo** audit engagement by running `mitigation-review-single.sh`. The script is the source of truth. Do not reimplement its steps by hand; run it.

Script: `/Users/stalinmacias/Documents/0xStalin/Audits/Tools/automation-tooling-auditor-workflow/mitigation_review/single-repo/mitigation-review-single.sh`
(Always use this repo path, not `mitigation-review-single` on PATH, which may be an older copy.)

What the script does:
1. Merges the client's commits up to the fix commit into `audit-fixes`, keeping their original hashes.
2. Verifies the merge.
3. Pushes `audit-fixes` to `origin`. This skill runs it without `--push`, so it never pushes by itself.
4. Merges `audit-fixes` into the local `mitigation-review` branch (`MITIGATION_REVIEW/` worktree). The user's uncommitted work there is kept as it is.

`mitigation-review` is local only. Never push it.

## Inputs

- **Client repo URL** (required): e.g. `https://github.com/client-org/protocol.git`.
- **Fix commit hash** (required): the commit the fixes go up to. It should be the full 40-character hash. A short hash only works if the commit is on a client branch. If the user gives a short hash, warn them and ask for the full one.

If either is missing, ask for it.

## Steps

### 1. Gate: the current directory must be on `audit-fixes`

This skill only runs when the current working directory is in a worktree that has the `audit-fixes` branch checked out. This is a hard rule, so the user can't run it in the wrong place by mistake. Check it first, before anything else:
```bash
git branch --show-current
```

If the output is not exactly `audit-fixes` (another branch, empty for a detached HEAD, or an error because this is not a git repo), **stop**. Do not run the script, do not look for the `AuditFixes/` worktree yourself, do not `cd` anywhere, and do not offer to run it from another directory. Tell the user:
- the current directory and the branch it is on (or that it is not a git repo), and
- that `/pull-fixes` must be run from the `AuditFixes/` worktree of the engagement.

If the engagement holds several client repos, each in its own folder, this skill does not apply. Point the user to `mitigation-review-multi` instead.

### 2. Run the script (no push)

From the current directory. Do not `cd`:
```bash
/Users/stalinmacias/Documents/0xStalin/Audits/Tools/automation-tooling-auditor-workflow/mitigation_review/single-repo/mitigation-review-single.sh <client-repo-url> <fix-commit-hash>
```

Do not pass `--push`. Without a terminal, the script does not push. It prints `Not pushed. When ready: ...` and then still syncs `MITIGATION_REVIEW`.

### 3. Report

Summarize the output for the user:
- **Client commits brought in:** the range and the `git log --oneline` list the script printed.
- **Verification:** both `OK:` lines, or the `WARNING`/`MISSING` lines.
- **MITIGATION_REVIEW sync:** the result. Either it synced and the user's uncommitted work is untouched (name the backup ref if one was made), or it was refused or skipped and why. If git listed files, list them: the fixes change files the user edited in `MITIGATION_REVIEW/` without committing. Tell them to commit or stash those files, then run `/pull-fixes` again with the same hash, which retries just the sync.

Handle these outcomes:

| Output | Meaning and what to do |
|--------|------------------------|
| `Nothing to do: ... is already in audit-fixes` | That fix commit was already merged. The script still syncs `MITIGATION_REVIEW`. Report that result. Do not offer to push unless `audit-fixes` is ahead of `origin/audit-fixes` |
| `Merge stopped — resolve these conflicts manually` | A merge into `audit-fixes` is still in progress in `AuditFixes/`. Show the conflicted files. Do not resolve, abort, or push. Ask the user how to proceed |
| `Not pushing because verification reported problems` | Show the warnings. Do not push. The user decides |
| `no common history between ...` | The audit repo was imported without the client's history. The script can't be used. Tell the user |
| Any other `ERROR:` | Show it as is. Do not work around it |

### 4. Push audit-fixes, only after confirmation

Only when verification passed. Ask the user whether to push `audit-fixes` to the Cyfrin repo (`origin`). Push only on a clear yes:
```bash
git push -u origin audit-fixes
```

Push `audit-fixes` only. Never push `mitigation-review` or the `refs/mitigation-review-backups/*` refs.
