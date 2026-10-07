# Mitigation Review

Scripts for the mitigation review phase: bringing the client's fixes into the audit repo for review. Pick the one that matches how the audit repo is laid out:

| Folder | Use when | Script |
|--------|----------|--------|
| [`single-repo/`](single-repo/README.md) | The audit repo **is** one client repo (code at the root, imported with the client's history) | `mitigation-review-single <client_repo_url> <fix_commit_hash>` |
| [`multi-repo/`](multi-repo/README.md) | The audit repo holds **several** client repos, each in its own folder (subtree) | `mitigation-review-multi <config_file>` |

Both merge the client's fixes at a specific commit hash.
