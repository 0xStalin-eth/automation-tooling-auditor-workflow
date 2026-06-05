#!/usr/bin/env bash
#
# Mitigation review setup
# -----------------------
# Creates a worktree, pulls each source repo's fix branch into its own
# subtree folder, then pushes the review branch to the audit repo.
#
set -euo pipefail

# --- Phase 1: create the worktree (inherits the existing subtree folders) ----
git worktree add -b Mitigation_Review MitigationReview
cd MitigationReview

# --- Phase 2: parameterized "add remote + pull its fix branch" ---------------
# Shell variable names can't contain hyphens, so the params you named map to:
#   remote-name             -> remote_name
#   exact-folder-name       -> exact_folder_name
#   mitigations-branch-name -> mitigations_branch_name
add_and_pull() {
  local remote_name="$1"
  local remote_url="$2"
  local exact_folder_name="$3"
  local mitigations_branch_name="$4"

  # Add the remote if missing; otherwise just refresh its URL (idempotent).
  git remote add "$remote_name" "$remote_url" 2>/dev/null \
    || git remote set-url "$remote_name" "$remote_url"

  # Pull the fix branch into its folder. -m avoids the interactive merge editor.
  git subtree pull \
    --prefix="$exact_folder_name" \
    -m "Merge ${mitigations_branch_name} into ${exact_folder_name}" \
    "$remote_name" "$mitigations_branch_name"
}

# One call per source repo:
#   add_and_pull  <remote_name>  <remote_url>  <exact_folder_name>  <mitigations_branch_name_on_remote-repo>
# where:
# remote_name -> name for the remote reference
# remote_url  -> remote repo's url
# exact_folder_name -> folder name where changes will be pulled in - Must match the same name on the internal repo
# mitigations_branch_name_on_remote-repo -> Branch's name for the mitigations on the remote

#   add_and_pull  <remote_name>  <remote_url>  <exact_folder_name>  <mitigations_branch_name_on_remote-repo>

################################ Example ##################################################
# Pull from two external repos into the internal repo # 
#
#add_and_pull ess-common \
#  https://github.com/USD-Pi-Protocol/stbl-contracts-evm-ess-common.git \
#  stbl-contracts-evm-ess-common \
#  feat/cyfrin-issue-2-fix

#add_and_pull evm-redemptions \
#  https://github.com/USD-Pi-Protocol/stbl-contracts-evm-redemptions.git \
#  stbl-contracts-evm-redemptions \
#  feat/CHANGE_ME          # <-- set the redemptions fix branch (pull name from GitHub)
###########################################################################################
# --- Push the review branch to the audit repo --------------------------------
git push -u origin Mitigation_Review
