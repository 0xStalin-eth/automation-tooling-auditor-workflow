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
