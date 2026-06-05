# Mitigation Review

Sets up the mitigation review workspace for an audit engagement. Creates a dedicated worktree, pulls each client repo's fix branch into its own subtree folder, and pushes the review branch to the audit repo.

## Requirements

- `git`
- Access to the audit repo and all client fix repos

## Setup

Make the script executable and put it on your PATH (only needed once):
```bash
chmod +x mitigation-review.sh
cp mitigation-review.sh /usr/local/bin/mitigation-review
```

## Before running

Edit the script and update each `add_and_pull` call with the correct values for the engagement:

```bash
add_and_pull <remote_name> <remote_url> <exact_folder_name> <mitigations_branch_name>
```

| Param | Description |
|-------|-------------|
| `remote_name` | Short alias for the remote (no spaces or hyphens issues — use underscores) |
| `remote_url` | Full HTTPS or SSH URL of the client repo |
| `exact_folder_name` | The subtree folder name inside the worktree |
| `mitigations_branch_name` | The fix branch name on the client repo (get it from GitHub) |

Make sure to replace any `CHANGE_ME` placeholders before running.

## Usage

Run from the audit repo root:
```bash
mitigation-review
```

## What it does

1. Creates a new `Mitigation_Review` branch and checks it out as a worktree at `MitigationReview/`
2. For each client repo: adds it as a remote (idempotent) and pulls its fix branch into its subtree folder
3. Pushes `Mitigation_Review` to the audit repo's `origin`
