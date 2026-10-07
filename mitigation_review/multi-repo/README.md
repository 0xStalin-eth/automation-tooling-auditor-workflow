# Mitigation Review — Multi-Repo

For audit repos that contain **several client repos, each in its own folder** (subtree). If the audit repo is a single client repo with its code at the root, use [`../single-repo`](../single-repo/README.md) instead.

Sets up the mitigation review workspace for an audit engagement. Creates a dedicated worktree, merges a specific fix commit from each client repo into its own subtree folder, and pushes the review branch to the audit repo.

## Requirements

- `git`
- Access to the audit repo and all client fix repos

## Setup

Make the script executable and put it on your PATH (only needed once):
```bash
chmod +x mitigation-review-multi.sh
cp mitigation-review-multi.sh /usr/local/bin/mitigation-review-multi
```

## Before running

Create a config file listing the repos and fix commits for the engagement (one per line):
```bash
cp config/mitigations.example.txt config/mitigations.txt
vi config/mitigations.txt
```

Each line has 4 whitespace-separated fields:
```
<remote_name>  <remote_url>  <exact_folder_name>  <commit_hash>
```

| Field | Description |
|-------|-------------|
| `remote_name` | Short alias for the remote (use underscores, no spaces) |
| `remote_url` | Full HTTPS or SSH URL of the client repo |
| `exact_folder_name` | The subtree folder in the audit repo; it must already exist |
| `commit_hash` | The commit on the client repo containing the fixes (copy from GitHub). Use the full 40-char hash; a short hash only works if the commit is reachable from a branch on the remote |

Blank lines and lines starting with `#` are ignored. `config/mitigations*.txt` is gitignored (except the example).

## Usage

Run from the top level of a checkout of the audit repo — where the subtree folders are visible (not from inside one of them), passing the config file:
```bash
mitigation-review-multi /path/to/mitigations.txt
```

The config is validated first (field count, folder exists, no `CHANGE_ME` left); nothing is created if it fails.

## What it does

1. Validates the config file
2. Creates a new `Mitigation_Review` branch and checks it out as a worktree at `MitigationReview/`
3. For each config line: adds it as a remote (idempotent), fetches the commit, and merges exactly that commit into its subtree folder
4. Pushes `Mitigation_Review` to the audit repo's `origin`
