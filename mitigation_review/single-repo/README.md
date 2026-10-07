# Mitigation Review — Single-Repo

For audit repos that **are a single client repo**: the client's code sits at the root and was imported **with the client's git history**. If the audit repo holds several client repos, each in its own folder, use [`../multi-repo`](../multi-repo/README.md) instead.

Merges the client's fix commit into the `audit-fixes` branch, keeping **every client commit with its original hash** (no squashing), verifies the result, and pushes it to the audit repo.

## Requirements

- `git`
- Read access to the client repo, push access to the audit repo
- The `AuditFixes/` worktree on branch `audit-fixes` (created by [`setup-audit`](../../audit_setup/README.md))

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

## What it does

1. **Preconditions:** you're on `audit-fixes`, there are no uncommitted changes, and no merge is in progress
2. **Fetch:** adds or refreshes a `client` remote, fetches it, and fetches the fix commit by hash (this also covers commits that aren't on any branch)
3. **Finds the starting point automatically:** `git merge-base` returns the client commit the audit repo was imported at (first round) or the previous fix commit (later rounds), then lists the client commits being brought in
4. **Merges** with `--no-ff`, which keeps every client commit and its original hash and adds one merge commit
5. **Resolves the expected conflicts:** files you deleted under `.github/` (e.g. the client's CI workflows) that the client modified stay deleted. Any other conflict stops the script with the merge still in progress, so you can resolve it (`git add <files> && git commit --no-edit`) or back out (`git merge --abort`)
6. **Verifies:** every client commit is in `audit-fixes`, and the code outside `.github/` matches the fix commit exactly
7. **Pushes** `audit-fixes` to `origin`. If verification reported a problem, it never pushes

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
