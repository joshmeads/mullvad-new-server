#!/usr/bin/env bash

# Update these paths if required
mullvad=/usr/local/bin/mullvad
shuf=/opt/homebrew/bin/shuf

# Regions
VALID_REGIONS=$($mullvad relay list | grep -Eo "^(\w+\s?)+\s\(\w{2}\)" | sed "s/.*(\\(.*\\))/\\1/")
REGION=${1:-"\w{2}"}

# Return if a valid region or wildcard is selected
if [[ $REGION == '\w{2}' ]] || [[ $VALID_REGIONS =~ (^|[[:space:]])$REGION($|[[:space:]]) ]]; then
  true
else
  echo "$(date "+%Y/%m/%d %X %Z") :: Invalid Region Selected :: ${REGION:-"undefined"}" >>./reconnect.log
  exit 1
fi

# Patterns
GREP_PATTERN_ALL="\w{2}-\w*-wg-\d{3}"
GREP_PATTERN_REGION="$REGION-\w*-wg-\d{3}"

# Get the current server
function currentServer() {
  $mullvad relay get | grep -Eo $GREP_PATTERN_ALL
}
# Select a new server from the list
function newServer() {
  $mullvad relay list | grep -Eo $GREP_PATTERN_REGION | $shuf -n 1
}

# Set server variables
CURRENT_SERVER=$(currentServer)
RAND_SERVER=$(newServer)

# Check the selected server isn't the same as the currently selected server. Max 10 retries + some safety checks
function ensureNewServer() {
  for _ in {1..10}; do
    [[ ${#CURRENT_SERVER} -lt 5 ]] && break
    [[ "$CURRENT_SERVER" != "$RAND_SERVER" ]] && break
    echo "$(date "+%Y/%m/%d %X %Z") :: Duplicate server - retrying :: ${CURRENT_SERVER:-"none"}" >>./reconnect.log
    RAND_SERVER=$(newServer)
  done
  if [[ ${#CURRENT_SERVER} -lt 5 && "$CURRENT_SERVER" != "$RAND_SERVER" ]]; then
    echo "$(date "+%Y/%m/%d %X %Z") :: Unable to find a non duplicate server :: ${CURRENT_SERVER:-"none"} -> ${RAND_SERVER:-"error"}" >>./reconnect.log
    exit 1
  fi
}

#################### Main ####################
ensureNewServer

OUT=$($mullvad relay set hostname $RAND_SERVER | grep -Eo $GREP_PATTERN_ALL)
echo "$(date "+%Y/%m/%d %X %Z") :: ${CURRENT_SERVER:-"none"} -> ${OUT:-"error"}" >>./reconnect.log
