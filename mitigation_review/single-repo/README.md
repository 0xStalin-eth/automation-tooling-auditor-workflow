# Mitigation Review — Single-Repo

For audit repos that **are a single client repo**: the client's code sits at the root and was imported **with the client's git history**. If the audit repo holds several client repos, each in its own folder, use [`../multi-repo`](../multi-repo/README.md) instead.

Merges the client's fix commit into the `audit-fixes` branch, keeping **every client commit with its original hash** (no squashing), verifies the result, and pushes it to the audit repo. Then it merges `audit-fixes` into the `mitigation-review` branch, where the review is done.

## Requirements

- `git`
- Read access to the client repo, push access to the audit repo
- The `AuditFixes/` worktree on branch `audit-fixes` (created by [`setup-audit`](../../audit_setup/README.md))
- Optional: the `MITIGATION_REVIEW/` worktree on branch `mitigation-review` (also created by `setup-audit`). If it's missing, the sync step is skipped

## Setup

Make the script executable and put it on your PATH (only needed once):
```bash
chmod +x mitigation-review-single.sh
cp mitigation-review-single.sh /usr/local/bin/mitigation-review-single
```

## Usage

From inside the `AuditFixes/` worktree:
```bash
cd <engagement>/AuditFixes
mitigation-review-single <client_repo_url> <fix_commit_hash>
```

Example (the URL is the client repo, the hash is the commit the fixes go up to):
```bash
mitigation-review-single https://github.com/client-org/protocol.git 3f9c2a1b7e4d5c6a8b9f0e1d2c3b4a5f6e7d8c9b
```

| Option | Description |
|--------|-------------|
| `--push` | Push to `origin` without asking. Without it, the script asks (or, when not run interactively, prints the push command) |

Use the full 40-char commit hash. A short hash only works if the commit is on a branch of the client repo.

For later fix rounds, run it again with the new fix commit. Only the commits added since the previous round are merged and verified.

### As a Claude Code skill

The `/pull-fixes` skill (`.claude/skills/pull-fixes/`) runs this script. Like the script, it only runs from the `AuditFixes/` worktree (branch `audit-fixes`), and refuses anywhere else. It summarizes the commits brought in, the verification and the `MITIGATION_REVIEW` sync, and pushes `audit-fixes` only after you confirm. To make it available in any engagement, symlink it into your user skills from the repo root (only needed once):
```bash
ln -s "$PWD/.claude/skills/pull-fixes" ~/.claude/skills/pull-fixes
```

Then, in Claude Code: `/pull-fixes <client_repo_url> <fix_commit_hash>`

## What it does

1. **Preconditions:** you're on `audit-fixes`, there are no uncommitted changes, and no merge is in progress
2. **Fetch:** adds or refreshes a `client` remote, fetches it, and fetches the fix commit by hash (this also covers commits that aren't on any branch)
3. **Finds the starting point automatically:** `git merge-base` returns the client commit the audit repo was imported at (first round) or the previous fix commit (later rounds), then lists the client commits being brought in
4. **Merges** with `--no-ff`, which keeps every client commit and its original hash and adds one merge commit
5. **Resolves the expected conflicts:** files you deleted under `.github/` (e.g. the client's CI workflows) that the client modified stay deleted. Any other conflict stops the script with the merge still in progress, so you can resolve it (`git add <files> && git commit --no-edit`) or back out (`git merge --abort`)
6. **Verifies:** every client commit is in `audit-fixes`, and the code outside `.github/` matches the fix commit exactly
7. **Pushes** `audit-fixes` to `origin`. If verification reported a problem, it never pushes
8. **Syncs the review branch:** merges `audit-fixes` into `mitigation-review` in the `MITIGATION_REVIEW/` worktree. Your review work there, committed or not, is never lost:
   - **Uncommitted work** (edited, staged, and untracked files) stays exactly as it is. Before merging, the script backs it up to `refs/mitigation-review-backups/<timestamp>`, without touching your files. After merging, it checks that every file you had changed is byte-for-byte the same. Files matched by `.gitignore` (e.g. `out/`, `cache/`) are not backed up. Git leaves them alone, unless a fix adds a tracked file at the same path
   - **A fix changes a file you edited but didn't commit:** git refuses the merge and lists the file. Nothing is touched. Commit or stash that file, then re-run with the same fix commit, which retries just the sync
   - **Committed review work** is kept: without review commits the branch fast-forwards, and with them the fixes are merged on top. With review commits, staged (`git add`ed) files also block the merge the same way
   - **Conflicts with your commits:** the merge is aborted, so `MITIGATION_REVIEW/` is left exactly as it was
   - **A merge in progress** in `MITIGATION_REVIEW/`: the sync is skipped

   To look at or restore a backup:
   ```bash
   git for-each-ref refs/mitigation-review-backups/                       # list backups
   git diff HEAD refs/mitigation-review-backups/<timestamp> --stat          # what's in one
   git checkout refs/mitigation-review-backups/<timestamp> -- <file>       # restore a file
   ```

## When it stops

| Message | Meaning |
|---------|---------|
| `no common history between ...` | The audit repo was imported as a plain copy, without the client's history. This script can't be used, so merge manually |
| `code outside .github/ differs from ...` | The merge succeeded but `audit-fixes` has changes the client doesn't have (e.g. an auditor-added file). Review the listed files, then push manually if expected |
| `Nothing to do: ... is already in audit-fixes` | That fix commit was already merged |

## Reviewing the fixes

```bash
git log --oneline --no-merges <previous_tip>..audit-fixes   # the client's fix commits, original hashes
git diff <previous_tip>..audit-fixes                        # the whole change at once
```
