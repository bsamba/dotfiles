#!/usr/bin/env bash
# runner-watchdog.sh — restart self-hosted runner containers that are
# unhealthy (per docker healthcheck) or that GitHub reports as not online.
#
# Detection layers:
#   1. docker health=unhealthy -> catches hung listeners with no broker
#      connection (healthcheck requires an established :443 connection)
#   2. GitHub API runner status -> ground truth; catches hangs that keep a
#      dead socket open (GitHub marks the runner offline after ~5 min)
#
# Invoked by runner-watchdog.timer every 5 minutes.
set -u

COMPOSE_DIR="${1:-/data/runners}"
ORG="n3otech"
RUNNER_CONTAINERS=(runner-001 runner-002)

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*"; }

# 1) Restart containers docker considers unhealthy
for c in $(docker ps --filter health=unhealthy --format '{{.Names}}'); do
  log "container $c is unhealthy -> restarting"
  docker restart "$c" || log "ERROR: failed to restart $c"
done

# 2) Ask GitHub which runners are online (single API call)
declare -A STATUS
while IFS='|' read -r name st; do
  [ -n "$name" ] && STATUS["$name"]="$st"
done < <(gh api "orgs/$ORG/actions/runners" \
  --jq '.runners[] | [.name, .status] | @tsv' 2>/dev/null | tr '\t' '|')

if [ "${#STATUS[@]}" -eq 0 ]; then
  log "WARN: could not fetch runner status from GitHub; skipping API check"
  exit 0
fi

for c in "${RUNNER_CONTAINERS[@]}"; do
  running=$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)
  [ "$running" = "true" ] || continue
  name=$(docker exec "$c" sed -n 's/.*"agentName": "\([^"]*\)".*/\1/p' /home/runner/.runner 2>/dev/null)
  [ -n "$name" ] || { log "WARN: could not determine runner name for $c"; continue; }
  st="${STATUS[$name]:-missing}"
  if [ "$st" != "online" ]; then
    log "runner $name reported '$st' by GitHub -> restarting $c"
    docker restart "$c" || log "ERROR: failed to restart $c"
  fi
done
