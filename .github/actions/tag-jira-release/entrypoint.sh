#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Pass the arguments to the Node.js application
if [ "$DRY_RUN" == "true" ]; then
  $SCRIPT_DIR/jira_tag_tickets.sh --dry-run
else
  bash -xv $SCRIPT_DIR/jira_tag_tickets.sh
fi
