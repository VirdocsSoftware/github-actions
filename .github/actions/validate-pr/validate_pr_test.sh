
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
  export TARGET_BRANCH="develop"
}

beforeAll

echo Scenario: Invalid PR title for feature branch
beforeEach

# GIVEN
export PR_TITLE="This is a PR title (ISSUE-1234)"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "PR title must start with a valid semantic prefix (e.g., feat:, fix:)."


