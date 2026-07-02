import json
import os
import subprocess
import sys
from pathlib import Path


def load_env_file(path):
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip().strip('"').strip("'"))


load_env_file(Path(__file__).parent.parent / ".env")

GITHUB_REPO = os.getenv("GITHUB_REPO")  # "owner/repo" or full GitHub URL


def parse_repo(value):
    # Accept "https://github.com/owner/repo" or "owner/repo"
    if value.startswith("http"):
        parts = value.rstrip("/").split("github.com/")[-1].split("/")
        return f"{parts[0]}/{parts[1]}"
    return value


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python scripts/open_issues.py <config/open_numbers.txt> [repo_url]")
        print("  python scripts/open_issues.py 1 2 3 4 5 [repo_url]")
        sys.exit(1)

    # Detect inline numbers vs file path: if the first arg is all digits, treat all
    # digit args as issue numbers and the last arg (if non-digit) as the repo.
    args = sys.argv[1:]
    if args[0].isdigit():
        digit_args = [a for a in args if a.isdigit()]
        non_digit_args = [a for a in args if not a.isdigit()]
        numbers = [int(a) for a in digit_args]
        repo = parse_repo(non_digit_args[0] if non_digit_args else GITHUB_REPO)
    else:
        with open(args[0]) as f:
            numbers = [int(line.strip()) for line in f if line.strip()]
        repo = parse_repo(args[1] if len(args) > 1 else GITHUB_REPO)

    if not repo:
        print("Error: repo not provided. Pass it as argument, set GITHUB_REPO in gh_issues/.env, or export it in your shell")
        sys.exit(1)

    opened = 0
    failed = 0

    for number in numbers:
        result = subprocess.run(
            [
                "gh", "api",
                "--method", "PATCH",
                f"/repos/{repo}/issues/{number}",
                "-f", "state=open",
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            print(f"[OK]   #{data['number']} reopened — {data['title']}")
            opened += 1
        else:
            msg = (result.stderr or result.stdout).strip()
            print(f"[FAIL] #{number}: {msg}")
            failed += 1

    print(f"\nDone. Opened: {opened}  Failed: {failed}")


if __name__ == "__main__":
    main()
