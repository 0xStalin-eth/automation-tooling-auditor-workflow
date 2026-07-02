# GitHub Issue Manager

Python scripts to bulk open and close GitHub issues by issue number.

Auth is delegated to the [GitHub CLI](https://cli.github.com/) (`gh`), which stores your token in the OS keyring — no `GITHUB_TOKEN` file needed.

## Structure

```
gh_issues/
├── README.md
├── .env                              # per-project GITHUB_REPO (gitignored, optional)
├── scripts/
│   ├── open_issues.py
│   └── close_issues.py
└── config/
    ├── open_numbers.example.txt
    ├── close_numbers.example.txt
    ├── open_numbers.txt              # issue numbers to reopen (gitignored)
    └── close_numbers.txt             # issue numbers to close (gitignored)
```

## Requirements

- Python 3 (stdlib only — no third-party packages)
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

## Setup

**1. Install and authenticate `gh`:**
```bash
brew install gh          # macOS; see https://cli.github.com for other platforms
gh auth login            # store the token in the OS keyring
gh auth status           # verify you're logged in
```

For repos owned by a GitHub **organization**, make sure your `gh` login has access to that org (`gh auth refresh -s repo` if the token lacks scopes, or authorize the org under your GitHub SSO settings).

**2. Point the scripts at a repo.** Pick one:

- **Per-project (recommended for one-off audits)** — create `gh_issues/.env`:
  ```
  GITHUB_REPO=https://github.com/owner/repo
  ```
  The scripts auto-load this file. `.env` is gitignored.

- **Shell-wide** — export it once for all projects:
  ```bash
  export GITHUB_REPO=https://github.com/owner/repo
  ```

- **Inline** — pass the repo URL as the last CLI arg on every run (see Usage).

**3. Prepare your issue number files:**
```bash
cp gh_issues/config/open_numbers.example.txt gh_issues/config/open_numbers.txt
cp gh_issues/config/close_numbers.example.txt gh_issues/config/close_numbers.txt
```

Edit each file with the issue numbers you want to act on, one per line:
```
1
2
3
```

## Usage

**Reopen issues — inline numbers:**
```bash
python gh_issues/scripts/open_issues.py 1 2 3 4 5 6
```

**Close issues — inline numbers:**
```bash
python gh_issues/scripts/close_issues.py 1 2 3 4 5 6
```

**Using a numbers file instead:**
```bash
python gh_issues/scripts/open_issues.py gh_issues/config/open_numbers.txt
python gh_issues/scripts/close_issues.py gh_issues/config/close_numbers.txt
```

**Override the repo inline (appended after the numbers or file path):**
```bash
python gh_issues/scripts/open_issues.py 1 2 3 https://github.com/owner/repo
python gh_issues/scripts/close_issues.py 1 2 3 https://github.com/owner/repo

python gh_issues/scripts/open_issues.py gh_issues/config/open_numbers.txt https://github.com/owner/repo
python gh_issues/scripts/close_issues.py gh_issues/config/close_numbers.txt https://github.com/owner/repo
```
