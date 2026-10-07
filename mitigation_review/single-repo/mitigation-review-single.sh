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
#
# Usage (from inside the AuditFixes/ worktree):
#   mitigation-review-single [--push] <client_repo_url> <fix_commit_hash>
#
#   --push  push to origin without asking
#
set -euo pipefail

BRANCH="audit-fixes"      # branch the fixes are merged into
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
