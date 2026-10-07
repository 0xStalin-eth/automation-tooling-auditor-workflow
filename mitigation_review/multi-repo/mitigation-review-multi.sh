#!/usr/bin/env bash
#
# Mitigation review setup — MULTI-REPO audits
# --------------------------------------------
# For audit repos that hold several client repos, each in its own folder
# (subtree). For an audit repo that IS a single client repo, use
# ../single-repo/mitigation-review-single.sh instead.
#
# Creates a worktree, merges a specific fix commit from each source repo into
# its own subtree folder, then pushes the review branch to the audit repo.
#
# Usage (from the audit repo root):
#   mitigation-review-multi <config_file>
#
# Config file: one source repo per line, 4 whitespace-separated fields:
#   <remote_name>  <remote_url>  <exact_folder_name>  <commit_hash>
# Blank lines and lines starting with # are ignored.
# See config/mitigations.example.txt
#
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: mitigation-review-multi <config_file>" >&2
  exit 1
fi

config_file="$1"
if [[ ! -f "$config_file" ]]; then
  echo "ERROR: config file not found: ${config_file}" >&2
  exit 1
fi
# Absolute path, since we cd into the worktree before reading it.
config_file="$(cd "$(dirname "$config_file")" && pwd)/$(basename "$config_file")"

# --- Phase 0: validate the config before touching the repo -------------------
entries=0
line_no=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_no=$((line_no + 1))
  [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
  read -r -a fields <<< "$line"
  if [[ ${#fields[@]} -ne 4 ]]; then
    echo "ERROR: ${config_file}:${line_no}: expected 4 fields, got ${#fields[@]}: ${line}" >&2
    exit 1
  fi
  if [[ ! -d "${fields[2]}" ]]; then
    echo "ERROR: ${config_file}:${line_no}: folder '${fields[2]}' does not exist in this repo" >&2
    exit 1
  fi
  if [[ "${fields[3]}" == *CHANGE_ME* ]]; then
    echo "ERROR: ${config_file}:${line_no}: replace the CHANGE_ME placeholder" >&2
    exit 1
  fi
  entries=$((entries + 1))
done < "$config_file"

if [[ $entries -eq 0 ]]; then
  echo "ERROR: no repos listed in ${config_file}" >&2
  exit 1
fi

# --- Phase 1: create the worktree (inherits the existing subtree folders) ----
git worktree add -b Mitigation_Review MitigationReview
cd MitigationReview

# --- Phase 2: parameterized "add remote + pull its fix commit" ---------------
# Shell variable names can't contain hyphens, so the params you named map to:
#   remote-name        -> remote_name
#   exact-folder-name  -> exact_folder_name
#   commit-hash        -> commit_hash
add_and_pull() {
  local remote_name="$1"
  local remote_url="$2"
  local exact_folder_name="$3"
  local commit_hash="$4"

  # Add the remote if missing; otherwise just refresh its URL (idempotent).
  git remote add "$remote_name" "$remote_url" 2>/dev/null \
    || git remote set-url "$remote_name" "$remote_url"

  # Fetch the remote's branches so the commit (full or short hash) resolves locally.
  git fetch "$remote_name"

  # Commit not reachable from any branch (e.g. force-pushed away)? Fetch it
  # directly by hash — this requires the full 40-char hash.
  if ! git rev-parse --verify --quiet "${commit_hash}^{commit}" >/dev/null; then
    git fetch "$remote_name" "$commit_hash" || {
      echo "ERROR: commit ${commit_hash} not found on ${remote_name} (use the full hash)" >&2
      exit 1
    }
  fi

  local full_hash
  full_hash="$(git rev-parse "${commit_hash}^{commit}")"

  # Merge that exact commit into its folder. -m avoids the interactive merge editor.
  git subtree merge \
    --prefix="$exact_folder_name" \
    -m "Merge ${remote_name}@${full_hash:0:12} into ${exact_folder_name}" \
    "$full_hash"
}

# --- Phase 3: one add_and_pull per config line --------------------------------
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
  read -r -a fields <<< "$line"
  add_and_pull "${fields[@]}" < /dev/null
done < "$config_file"

# --- Push the review branch to the audit repo --------------------------------
git push -u origin Mitigation_Review
