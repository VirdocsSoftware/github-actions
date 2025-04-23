#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function expect() {
  if [ "$1" != "$2" ]; then
    echo "Expected: $2"
    echo "Actual:   $1"
    exit 1
  else
    echo "OK"
  fi
}

beforeAll() {
  export TESTING=true
}

beforeEach() {
  export PR_TITLE="feat: This is a PR title (ISSUE-1234)"
  export PR_BRANCH="feature/ISSUE-1234"
  export LATEST_RELEASE="1.0.0"
  export PACKAGE_VERSION="1.1.0"
  export TARGET_BRANCH="develop"
}

beforeAll

echo Scenario: PR title missing semantic prefix for feature branch
beforeEach

# GIVEN
export PR_TITLE="This is a PR title (ISSUE-1234)"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "Error: Invalid PR title format
Details:
- Current title: This is a PR title (ISSUE-1234)
Action: Update the PR title to start with a valid semantic prefix
Valid prefixes: feat:, fix:, chore:, ci:, docs:, style:, refactor:, perf:, test:
Example: feat: Add new feature (ABC-123)
Note: You must push a new commit to update this validation result"

echo Scenario: PR title missing Jira ticket for feature branch
beforeEach

# GIVEN
export PR_TITLE="feat: This is a PR title"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "Error: Missing Jira ticket reference in PR title
Details:
- Current title: feat: This is a PR title
Action: Include a Jira ticket ID in the PR title using the format (ABC-123)
Example: feat: Add new feature (ABC-123)"

echo Scenario: PR title missing Jira ticket for feature branch targeting hotfix branch
beforeEach

# GIVEN
export PR_TITLE="feat: This is a PR title"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "Error: Missing Jira ticket reference in PR title
Details:
- Current title: feat: This is a PR title
Action: Include a Jira ticket ID in the PR title using the format (ABC-123)
Example: feat: Add new feature (ABC-123)"

echo Scenario: Valid PR title for feature branch
beforeEach

# GIVEN
export PR_TITLE="feat: This is a PR title (ISSUE-1234)"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"
expect "PR title and branch name validation passed." "$ACTUAL"

echo Scenario: Non release or hotfix branch targeting the main branch
beforeEach

# GIVEN
export PR_BRANCH="TICKET-123"
export TARGET_BRANCH="main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "Error: Invalid branch name for main target
Details:
- Current branch: TICKET-123
- Target branch: main
Action: Only release or hotfix branches can be merged to main
Expected format: release/v1.1.0 or hotfix/v1.1.0"

echo Scenario: Package version and branch name mismatch
beforeEach

# GIVEN
export PR_BRANCH="release/v1.1.0"
export TARGET_BRANCH="main"
export PACKAGE_VERSION="1.0.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "Error: Mismatch between the pull request branch and the package version.
Details:
- PR Branch: release/v1.1.0
- Latest Release: 1.0.0
- Package Version: 1.0.0
Action: Update the PR branch name or package version to ensure consistency. 
For more details on naming conventions, refer to our workflow documentation.
See: https://virdocs.atlassian.net/wiki/x/AYAqHAE"

echo Scenario: Next Release version is not higher than the latest version
beforeEach

# GIVEN
export PR_BRANCH="release/v1.0.0"
export TARGET_BRANCH="main"
export PACKAGE_VERSION="1.0.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "Error: Invalid version increment
Details:
- Current version: 1.0.0
- Latest release: 1.0.0
Action: Update the package version to be higher than the latest release
Example: If latest is 1.0.0, next version should be > 1.0.0 (e.g., 1.0.1, 1.1.0, 2.0.0)
For version numbering guidelines, see: https://semver.org/"

echo Scenario: Valid feature branch to develop branch
beforeEach

# GIVEN
export PR_BRANCH="feature/ISSUE-1234"
export TARGET_BRANCH="develop"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid feature branch to release branch
beforeEach

# GIVEN
export PR_BRANCH="feature/ISSUE-1234"
export TARGET_BRANCH="release/v1.1.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid feature branch to hotfix branch
beforeEach

# GIVEN
export PR_BRANCH="feature/ISSUE-1234"
export TARGET_BRANCH="hotfix/v1.1.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid release branch to main branch
beforeEach

# GIVEN
export PR_BRANCH="release/v1.1.0"
export TARGET_BRANCH="main"
export PR_TITLE="release v1.1.0 to main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid hotfix branch to main branch
beforeEach

# GIVEN
export PR_BRANCH="hotfix/v1.1.0"
export TARGET_BRANCH="main"
export PR_TITLE="hotfix v1.1.0 to main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid release branch merging to develop
beforeEach

# GIVEN
export PR_BRANCH="release/v1.1.0"
export TARGET_BRANCH="develop"
export PR_TITLE="release v1.1.0 to develop"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid pr title for fix branch merging to develop
beforeEach

# GIVEN
export PR_BRANCH="fix-PAR-2061-remove-unnecessary-message-types"
export TARGET_BRANCH="develop"
export PR_TITLE="fix(PAR-2061): Remove unnecessary message types"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Next release version has double digit and current release version has single digit
beforeEach

# GIVEN
export PR_BRANCH="release/v1.10.0"
export TARGET_BRANCH="main"
export PACKAGE_VERSION="1.10.0"
export LATEST_RELEASE="1.9.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid hotfix branch with suffix to main branch
beforeEach

# GIVEN
export PR_BRANCH="hotfix/v1.2.3-ar"
export TARGET_BRANCH="main"
export PACKAGE_VERSION="1.2.3"
export LATEST_RELEASE="1.2.2"
export PR_TITLE="hotfix v1.2.3 to main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"