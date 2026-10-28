#!/usr/bin/env bash
#
# Mitigation review setup — SINGLE-REPO audits
# ---------------------------------------------
# For audit repos that ARE a single client repo (client code at the root, imported
# with the client's git history). For audit repos holding several client repos in
# their own folders, use ../multi-repo/mitigation-review-multi.sh instead.
#
# Merges the client's fix commit into the audit-fixes branch, keeping every client
# commit with its original hash, verifies the result, then pushes to origin.
# Finally merges audit-fixes into the mitigation-review branch (MITIGATION_REVIEW/
# worktree), where the review itself is done.
#
# Usage (from inside the AuditFixes/ worktree):
#   mitigation-review-single [--push] <client_repo_url> <fix_commit_hash>
#
#   --push  push to origin without asking
#
set -euo pipefail

BRANCH="audit-fixes"      # branch the fixes are merged into
REVIEW_BRANCH="mitigation-review"  # review branch kept in sync with audit-fixes
REMOTE="client"           # remote name used for the client repo
KEEP_DELETED=".github/"   # files we deleted under this path stay deleted if the client modified them

usage() {
  echo "Usage: mitigation-review-single [--push] <client_repo_url> <fix_commit_hash>" >&2
  exit 1
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Snapshot every uncommitted change in a worktree (tracked and untracked, not
# ignored) as a commit, without touching its files or its index. Prints the hash.
snapshot() {
  local wt="$1" tmp_index tree
  tmp_index="$(mktemp)"
  cp "$(git -C "$wt" rev-parse --path-format=absolute --git-path index)" "$tmp_index"
  GIT_INDEX_FILE="$tmp_index" git -C "$wt" add -A
  tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$wt" write-tree)"
  rm -f "$tmp_index"
  git -C "$wt" commit-tree "$tree" -p HEAD -m "Snapshot of ${wt} before syncing ${REVIEW_BRANCH}"
}

# Merge audit-fixes into the review branch, in whichever worktree has it checked
# out. The review work there is usually uncommitted, so it must never be lost:
# git refuses any merge that would overwrite uncommitted or untracked files, a
# backup of them is saved first, and they are verified to be unchanged after.
sync_review() {
  local review_path
  review_path="$(git worktree list --porcelain | awk -v ref="branch refs/heads/${REVIEW_BRANCH}" \
    '/^worktree /{p=substr($0,10)} $0==ref{print p}')"

  echo
  if [[ -z "$review_path" ]]; then
    echo "Skipping ${REVIEW_BRANCH} sync: branch is not checked out in any worktree"
    return 0
  fi
  if git -C "$review_path" rev-parse -q --verify MERGE_HEAD >/dev/null; then
    echo "WARNING: skipping ${REVIEW_BRANCH} sync: a merge is in progress in ${review_path}" >&2
    return 0
  fi
  if git merge-base --is-ancestor "$BRANCH" "$REVIEW_BRANCH"; then
    echo "OK: ${REVIEW_BRANCH} already has everything in ${BRANCH}"
    return 0
  fi

  local before backup="" backup_ref=""
  before="$(git rev-parse "$REVIEW_BRANCH")"
  if [[ -n "$(git -C "$review_path" status --porcelain)" ]]; then
    backup="$(snapshot "$review_path")"
    backup_ref="refs/${REVIEW_BRANCH}-backups/$(date +%Y%m%d-%H%M%S)"
    git update-ref "$backup_ref" "$backup"
    echo "Backed up uncommitted work in ${REVIEW_BRANCH} to ${backup_ref}"
  fi

  # No review commits: fast-forward. Otherwise: a merge commit on top of them.
  local merged=true
  if git merge-base --is-ancestor "$REVIEW_BRANCH" "$BRANCH"; then
    git -C "$review_path" merge --ff-only "$BRANCH" || merged=false
  else
    git -C "$review_path" merge --no-edit -m "Merge ${BRANCH} into ${REVIEW_BRANCH}" "$BRANCH" || merged=false
  fi
  if [[ "$merged" != true ]]; then
    if git -C "$review_path" rev-parse -q --verify MERGE_HEAD >/dev/null; then
      git -C "$review_path" merge --abort
    fi
    echo >&2
    echo "Sync of ${REVIEW_BRANCH} aborted — ${review_path} is unchanged (still at ${before:0:12})." >&2
    echo "If git listed files above, the fixes change files you edited there: commit or stash them," >&2
    echo "then re-run this command with the same fix commit (or: git -C ${review_path} merge ${BRANCH})." >&2
    exit 1
  fi

  git merge-base --is-ancestor "$before" "$REVIEW_BRANCH" \
    || die "${REVIEW_BRANCH} no longer contains ${before:0:12} — recover it with: git -C ${review_path} reset --hard ${before}"

  # Every file that had uncommitted changes must still be exactly as it was.
  if [[ -n "$backup" ]]; then
    local after changed=()
    after="$(snapshot "$review_path")"
    while IFS= read -r -d '' f; do changed+=("$f"); done \
      < <(git diff -z --no-renames --name-only "$before" "$backup")
    if [[ ${#changed[@]} -gt 0 ]] && ! git diff --quiet "$backup" "$after" -- "${changed[@]}"; then
      echo "ERROR: uncommitted work in ${review_path} changed during the sync:" >&2
      git diff --stat "$backup" "$after" -- "${changed[@]}" >&2
      die "restore a file with: git -C ${review_path} checkout ${backup_ref} -- <file>"
    fi
    echo "OK: uncommitted work in ${REVIEW_BRANCH} is untouched"
  fi
  echo "Synced ${REVIEW_BRANCH}: $(git -C "$review_path" log -1 --format='%h %s')"
}

push=false
args=()
for arg in "$@"; do
  case "$arg" in
    --push) push=true ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $arg" >&2; usage ;;
    *) args+=("$arg") ;;
  esac
done
[[ ${#args[@]} -eq 2 ]] || usage
client_url="${args[0]}"
fix_commit="${args[1]}"

# --- Phase 0: preconditions ---------------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "not inside a git worktree — run this from AuditFixes/"
cd "$(git rev-parse --show-toplevel)"

current_branch="$(git symbolic-ref --short -q HEAD || true)"
[[ "$current_branch" == "$BRANCH" ]] \
  || die "on branch '${current_branch:-detached HEAD}', expected '${BRANCH}'"

if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  die "a merge is already in progress — finish it or run 'git merge --abort'"
fi
git diff --quiet && git diff --cached --quiet \
  || die "uncommitted changes — commit or stash them first"

# --- Phase 1: fetch the client repo and the fix commit -------------------------
git remote add "$REMOTE" "$client_url" 2>/dev/null \
  || git remote set-url "$REMOTE" "$client_url"
git fetch "$REMOTE"

# Commit not reachable from any client branch? Fetch it directly by hash —
# this requires the full 40-char hash.
if ! git rev-parse --verify --quiet "${fix_commit}^{commit}" >/dev/null; then
  git fetch "$REMOTE" "$fix_commit" \
    || die "commit ${fix_commit} not found on ${client_url} (use the full hash)"
fi
fix="$(git rev-parse "${fix_commit}^{commit}")"
fix_short="${fix:0:12}"

if git merge-base --is-ancestor "$fix" HEAD; then
  echo "Nothing to do: ${fix_short} is already in ${BRANCH}."
  sync_review
  exit 0
fi

# --- Phase 2: find where the client's new commits start -----------------------
# The merge base is the client commit the audit repo was imported at (first round)
# or the previous fix commit (later rounds).
base="$(git merge-base HEAD "$fix")" \
  || die "no common history between ${BRANCH} and ${fix_short} — the audit repo was not imported with the client's history"

total="$(git rev-list --count "${base}..${fix}")"
non_merge="$(git rev-list --count --no-merges "${base}..${fix}")"
echo
echo "Client commits to bring in: ${base:0:12}..${fix_short} (${total} commits, ${non_merge} non-merge)"
git log --oneline --reverse --no-merges "${base}..${fix}"
echo

# --- Phase 3: merge, keeping the client's original commit hashes --------------
if ! git merge --no-ff --no-edit -m "Merge client fixes up to ${fix_short}" "$fix"; then
  conflicted=()
  while IFS= read -r f; do conflicted+=("$f"); done < <(git diff --name-only --diff-filter=U)
  [[ ${#conflicted[@]} -gt 0 ]] || die "merge failed (see git output above)"

  unresolved=()
  for f in "${conflicted[@]}"; do
    # Deleted on our side: index has their version (stage 3) but no ours (stage 2).
    stages="$(git ls-files -u -- "$f" | awk '{print $3}' | sort -u | tr -d '\n')"
    if [[ "$f" == "$KEEP_DELETED"* && "$stages" != *2* && "$stages" == *3* ]]; then
      echo "Keeping deleted: $f"
      git rm -q -- "$f"
    else
      unresolved+=("$f")
    fi
  done

  if [[ ${#unresolved[@]} -gt 0 ]]; then
    echo >&2
    echo "Merge stopped — resolve these conflicts manually:" >&2
    printf '  %s\n' "${unresolved[@]}" >&2
    echo "Then: git add <files> && git commit --no-edit   (or: git merge --abort)" >&2
    exit 1
  fi
  git commit -q --no-edit
fi
echo "Merged: $(git log -1 --format='%h %s')"

# --- Phase 4: verify -----------------------------------------------------------
ok=true
missing=0
for c in $(git rev-list "${base}..${fix}"); do
  git merge-base --is-ancestor "$c" HEAD || { echo "MISSING client commit: $c" >&2; missing=$((missing + 1)); }
done
if [[ $missing -eq 0 ]]; then
  echo "OK: all ${total} client commits are in ${BRANCH} with their original hashes"
else
  ok=false
fi

if git diff --quiet "$fix" HEAD -- . ":!${KEEP_DELETED}"; then
  echo "OK: code outside ${KEEP_DELETED} matches ${fix_short} exactly"
else
  ok=false
  echo "WARNING: code outside ${KEEP_DELETED} differs from ${fix_short}:" >&2
  git diff --stat "$fix" HEAD -- . ":!${KEEP_DELETED}" >&2
fi

# --- Phase 5: push ------------------------------------------------------------
if [[ "$ok" != true ]]; then
  echo >&2
  echo "Not pushing because verification reported problems. Review them, then: git push -u origin ${BRANCH}" >&2
  exit 1
fi

if [[ "$push" != true ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Push ${BRANCH} to origin? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] && push=true
  fi
fi

if [[ "$push" == true ]]; then
  git push -u origin "$BRANCH"
else
  echo "Not pushed. When ready: git push -u origin ${BRANCH}"
fi

# --- Phase 6: sync the review branch -------------------------------------------
sync_review
