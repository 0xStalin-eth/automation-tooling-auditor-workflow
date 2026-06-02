import os
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_REPO = os.getenv("GITHUB_REPO")  # "owner/repo" or full GitHub URL


def parse_repo(value):
    # Accept "https://github.com/owner/repo" or "owner/repo"
    if value.startswith("http"):
        parts = value.rstrip("/").split("github.com/")[-1].split("/")
        return f"{parts[0]}/{parts[1]}"
    return value


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/open_issues.py <config/open_numbers.txt> [repo_url]")
        print("open_numbers.txt format: one issue number per line")
        sys.exit(1)

    json_file = sys.argv[1]
    repo = parse_repo(sys.argv[2] if len(sys.argv) > 2 else GITHUB_REPO)

    if not GITHUB_TOKEN:
        print("Error: GITHUB_TOKEN is not set.")
        sys.exit(1)

    if not repo:
        print("Error: repo not provided. Pass it as argument or set GITHUB_REPO in .env")
        sys.exit(1)

    with open(json_file) as f:
        numbers = [int(line.strip()) for line in f if line.strip()]

    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"token {GITHUB_TOKEN}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
    )

    opened = 0
    failed = 0

    for number in numbers:
        url = f"https://api.github.com/repos/{repo}/issues/{number}"
        resp = session.patch(url, json={"state": "open"})
        if resp.status_code == 200:
            data = resp.json()
            print(f"[OK]   #{data['number']} reopened — {data['title']}")
            opened += 1
        else:
            msg = resp.json().get("message", resp.text)
            print(f"[FAIL] #{number}: {resp.status_code} {msg}")
            failed += 1

    print(f"\nDone. Opened: {opened}  Failed: {failed}")


if __name__ == "__main__":
    main()
