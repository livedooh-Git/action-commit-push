#!/usr/bin/env bash

set -e

# Return code
RET_CODE=0

#INPUT_ADD_TIMESTAMP=true

echo "Inputs:"
echo "  add_timestamp:       ${INPUT_ADD_TIMESTAMP}"
echo "  amend:               ${INPUT_AMEND}"
echo "  commit_prefix:       ${INPUT_COMMIT_PREFIX}"
echo "  commit_message:      ${INPUT_COMMIT_MESSAGE}"
echo "  force:               ${INPUT_FORCE}"
echo "  no_edit:             ${INPUT_NO_EDIT}"
echo "  organization_domain: ${INPUT_ORGANIZATION_DOMAIN}"
echo "  target_branch:       ${INPUT_TARGET_BRANCH}"
echo "  repository:          ${INPUT_REPOSITORY}"
echo "  deploy_env:          ${INPUT_DEPLOY_ENV}"
echo "  date_timestamp:      ${INPUT_DATE_TIMESTAMP}"

# Require github_token
if [[ -z "${GITHUB_TOKEN}" ]]; then
  # shellcheck disable=SC2016
  MESSAGE='Missing env var "github_token: ${{ secrets.GITHUB_TOKEN }}".'
  echo -e "[ERROR] ${MESSAGE}"
  exit 1
fi

# Set git credentials
git config --global safe.directory "${GITHUB_WORKSPACE}"
git config --global safe.directory /github/workspace
git remote set-url origin "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@${INPUT_ORGANIZATION_DOMAIN}/${INPUT_REPOSITORY}"
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.${INPUT_ORGANIZATION_DOMAIN}"

# Get changed files
git add -A
FILES_CHANGED=$(git diff --staged --name-status)
if [[ -n ${FILES_CHANGED} ]]; then
  echo -e "\n[INFO] Files changed:\n${FILES_CHANGED}"
else
  echo -e "\n[INFO] No files changed."
fi

# Setting branch name
BRANCH="${INPUT_TARGET_BRANCH:-$(git symbolic-ref --short -q HEAD)}"
# Add timestamp to branch name
if [[ "${INPUT_ADD_TIMESTAMP}" == "true" && -n ${FILES_CHANGED} ]]; then
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
  if [[ -n ${BRANCH} ]]; then
    BRANCH="${BRANCH}-${TIMESTAMP}"
  else
    BRANCH="${TIMESTAMP}"
  fi
fi

# Adding the timestamp to the branch
BRANCH="${INPUT_TARGET_BRANCH}-${INPUT_DATE_TIMESTAMP}"

echo -e "\n[INFO] Target branch: ${BRANCH}"

# Create a new branch
if [[ (-n "${INPUT_TARGET_BRANCH}" || "${INPUT_ADD_TIMESTAMP}" == "true") && -n ${FILES_CHANGED} ]]; then
  git checkout -b "${BRANCH}"
fi

# Create an auto commit
COMMIT_PARAMS=()
COMMIT_PARAMS+=("--allow-empty")
if [[ -n ${FILES_CHANGED} ]]; then
  echo "[INFO] Committing changes."
  if [[ "${INPUT_AMEND}" == "true" ]]; then
    COMMIT_PARAMS+=("--amend")
  fi
  if [[ "${INPUT_NO_EDIT}" == "true" ]]; then
    COMMIT_PARAMS+=("--no-edit")
    git commit "${COMMIT_PARAMS[@]}"
  elif [[ -n "${INPUT_COMMIT_MESSAGE}" || -n "${INPUT_COMMIT_PREFIX}" ]]; then
    git commit "${COMMIT_PARAMS[@]}" -am "${INPUT_COMMIT_PREFIX}${INPUT_COMMIT_MESSAGE}" -m "Files changed:\n${FILES_CHANGED}"
  else
    git commit "${COMMIT_PARAMS[@]}" -am "Files changed:" -m "${FILES_CHANGED}"
  fi
fi

if [[ "${DEPLOY_ENV}" == "app-livedooh" ]];
then
  # Rebase
  echo "[INFO] Rebase to target branch ${BRANCH}"
  git pull
fi

# Push
if [[ "${INPUT_FORCE}" == "true" ]]; then
  echo "[INFO] Force pushing changes"
  git push --force-with-lease origin "${BRANCH}"
elif [[ -n ${FILES_CHANGED} ]]; then
  echo "[INFO] Pushing changes"
  git push origin "${BRANCH}"
fi

# Finish
{
  echo "files_changed<<EOF"
  echo -e "${FILES_CHANGED}"
  echo "EOF"
  echo "branch_name=${BRANCH}"
} >> "${GITHUB_OUTPUT}"

if [[ ${RET_CODE} != "0" ]]; then
  echo -e "\n[ERROR] Check log for errors."
  exit 1
else
  # Pass in other cases
  echo -e "\n[INFO] No errors found."
  exit 0
fi
