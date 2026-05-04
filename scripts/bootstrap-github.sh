#!/usr/bin/env bash
# Create github.com/galalelatfawy/sagemaker-twitter-sentiment-terraform (if missing) and push main.
#
# SSH: uses Host "github-personal" from ~/.ssh/config — Git must rewrite git@github.com URLs.
# This script sets (in this repo only):
#   git config url."git@github-personal:".insteadOf "git@github.com:"
# For every repo: git config --global url."git@github-personal:".insteadOf "git@github.com:"
#
# Prerequisites (pick one):
#   1) gh auth login -h github.com -p ssh -w   # API token + SSH for git (recommended with github-personal)
#      or: gh auth login -h github.com -p https -w
#   2) export GH_TOKEN  # classic PAT with "repo" scope (HTTPS API; push still uses SSH + insteadOf)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Route github.com SSH through your Host alias so IdentityFile from ~/.ssh/config applies.
if [[ "${SKIP_GIT_SSH_INSTEADOF:-}" != "1" ]]; then
  git config url."git@github-personal:".insteadOf "git@github.com:"
  echo "Git: url.insteadOf set in this repo (github.com -> github-personal)."
fi

if command -v gh >/dev/null 2>&1; then
  gh config set git_protocol ssh --host github.com 2>/dev/null || true
fi

OWNER="${GITHUB_OWNER:-galalelatfawy}"
REPO_NAME="${GITHUB_REPO_NAME:-sagemaker-twitter-sentiment-terraform}"
FULL="${OWNER}/${REPO_NAME}"

create_via_api() {
  curl -fsS -X POST \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user/repos" \
    -d "{\"name\":\"${REPO_NAME}\",\"private\":false,\"description\":\"SageMaker Hugging Face sentiment (Terraform)\"}"
}

if [[ -n "${GH_TOKEN:-}" ]]; then
  echo "Creating repo via GitHub API (GH_TOKEN)..."
  if curl -fsS -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${GH_TOKEN}" "https://api.github.com/repos/${FULL}" | grep -q 200; then
    echo "Repo ${FULL} already exists."
  else
    create_via_api
    echo "Created ${FULL}."
  fi
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if gh repo view "${FULL}" >/dev/null 2>&1; then
    echo "Repo ${FULL} already exists."
  else
    echo "Creating ${FULL} with gh..."
    gh repo create "${FULL}" --public --description "SageMaker Hugging Face sentiment (Terraform)"
  fi
else
  echo "No GitHub authentication found."
  echo "  Option A (SSH + github-personal):"
  echo "    gh auth login -h github.com -p ssh -w"
  echo "    $0"
  echo "  Option B:  export GH_TOKEN=ghp_...   then re-run:  $0"
  exit 1
fi

echo "Pushing main -> origin..."
git push --set-upstream origin main
echo "Done: https://github.com/${FULL}"
