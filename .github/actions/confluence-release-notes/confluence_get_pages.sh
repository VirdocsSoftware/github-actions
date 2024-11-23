#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$CURL_CMD" == "" ]; then
    CURL_CMD="curl"
fi

JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"
ATLASSIAN_USER=$(echo $JIRA_CONFIG | jq -r .auth.user)
ATLASSIAN_API_TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
DOMAIN="$(echo $JIRA_CONFIG | jq -r .jira.domain)"

function get_page_by_id() {
    PAGE_ID=$1
    RESPONSE=$($CURL_CMD --silent --request GET \
    --url "https://$DOMAIN.atlassian.net/wiki/api/v2/pages/$PAGE_ID" \
    --user "$ATLASSIAN_USER:$ATLASSIAN_API_TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json')

    echo $RESPONSE
}

function url_encode() {
    local raw="$1"
    local encoded=""
    local length="${#raw}"
    for (( i = 0; i < length; i++ )); do
        local c="${raw:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) encoded+="$c" ;;
            *) encoded+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    echo "$encoded"
}

function get_page_by_title() {
    PAGE_TITLE="$1"
    RESPONSE=$($CURL_CMD --silent --request GET \
    --url "https://$DOMAIN.atlassian.net/wiki/api/v2/pages?title=$(url_encode "$PAGE_TITLE")" \
    --user "$ATLASSIAN_USER:$ATLASSIAN_API_TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json')

    echo $RESPONSE
}

function get_child_pages() {
    PAGE_ID=$1
    RESPONSE=$($CURL_CMD --silent --request GET \
    --url "https://$DOMAIN.atlassian.net/wiki/api/v2/pages/$PAGE_ID/children" \
    --user "$ATLASSIAN_USER:$ATLASSIAN_API_TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json')

    echo $RESPONSE
}

function main() {
    if [ "$1" == "" ]; then
        echo "Usage: <option> [page_id]"
        echo ""
        echo "  -i, --id <page_id>  The page id"
        echo "  -t, --title <title> The page title"
        echo "  -c, --children <page_id> Get the children of the page"
        exit 1
    fi

    OPTION=$1
    PAGE_ID=$2

    if [ "$OPTION" == "-i" ] || [ "$OPTION" == "--id" ]; then
        get_page_by_id $PAGE_ID
    elif [ "$OPTION" == "-t" ] || [ "$OPTION" == "--title" ]; then
        get_page_by_title "$PAGE_ID"
    elif [ "$OPTION" == "-c" ] || [ "$OPTION" == "--children" ]; then
        get_child_pages "$PAGE_ID"
    else
        echo "Invalid option: $OPTION"
        exit 1
    fi
}

main "$@"