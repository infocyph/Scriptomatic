#!/usr/bin/env bash
set -Eeuo pipefail

: "${MONGO_URI:=mongodb://127.0.0.1:27017}"
: "${MONGO_RS_NAME:=rs0}"
: "${MONGO_MEMBERS:=mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017}"
: "${MONGO_READY_TIMEOUT_SECONDS:=60}"
: "${MONGO_READY_INTERVAL_SECONDS:=2}"
: "${MONGO_INIT_TIMEOUT_SECONDS:=60}"
: "${MONGO_SHELL:=}"

log() {
  printf 'mongo-replica: %s\n' "$*" >&2
}

fatal() {
  log "$*"
  exit 1
}

validate_uint() {
  local name="$1" value="$2" min="$3" max="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || fatal "$name must be an integer"
  (( value >= min && value <= max )) || fatal "$name must be between $min and $max"
}

select_shell() {
  if [[ -n "$MONGO_SHELL" ]]; then
    command -v "$MONGO_SHELL" >/dev/null 2>&1 || fatal "configured Mongo shell not found: $MONGO_SHELL"
    printf '%s' "$MONGO_SHELL"
    return
  fi

  if command -v mongosh >/dev/null 2>&1; then
    printf '%s' mongosh
  elif command -v mongo >/dev/null 2>&1; then
    log "mongosh unavailable; using legacy mongo shell fallback"
    printf '%s' mongo
  else
    fatal "mongosh or legacy mongo shell is required"
  fi
}

parse_members() {
  local raw="$1" item
  IFS=',' read -r -a members <<<"$raw"
  ((${#members[@]} > 0)) || fatal "MONGO_MEMBERS must contain at least one member"

  local i
  for i in "${!members[@]}"; do
    item="${members[$i]}"
    [[ "$item" =~ ^[A-Za-z0-9._-]+:[0-9]{1,5}$ ]] || fatal "invalid Mongo replica member endpoint: $item"
    local port="${item##*:}"
    (( port >= 1 && port <= 65535 )) || fatal "invalid Mongo replica member port: $item"
  done
}

mongo_eval() {
  local script="$1"
  "$mongo_shell" --quiet "$MONGO_URI" --eval "$script"
}

wait_ready() {
  local deadline=$((SECONDS + MONGO_READY_TIMEOUT_SECONDS))
  until mongo_eval 'quit(db.adminCommand({ping:1}).ok === 1 ? 0 : 1)' >/dev/null 2>&1; do
    (( SECONDS < deadline )) || fatal "MongoDB did not become ready within ${MONGO_READY_TIMEOUT_SECONDS}s"
    sleep "$MONGO_READY_INTERVAL_SECONDS"
  done
}

js_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

build_members_js() {
  local out='' i host
  for i in "${!members[@]}"; do
    host="$(js_string "${members[$i]}")"
    [[ -z "$out" ]] || out+=','
    out+="{_id:${i},host:\"${host}\"}"
  done
  printf '%s' "$out"
}

check_topology() {
  local members_js="$1" rs_name="$2" script output rc
  script="const desired=[${members_js}]; try { const cfg=rs.conf(); if (cfg._id !== \"${rs_name}\") quit(42); if (!cfg.members || cfg.members.length !== desired.length) quit(42); for (let i=0;i<desired.length;i++){ if (cfg.members[i]._id !== desired[i]._id || cfg.members[i].host !== desired[i].host) quit(42); } quit(0); } catch (e) { const msg=String((e && (e.codeName || e.message)) || e); const code=(e && e.code) || 0; if (code === 94 || /NotYetInitialized|no replset config|not yet initialized/i.test(msg)) quit(3); print(msg); quit(43); }"

  set +e
  output="$(mongo_eval "$script" 2>&1)"
  rc=$?
  set -e

  case "$rc" in
    0) return 0 ;;
    3) return 3 ;;
    42) return 42 ;;
    *)
      log "unable to inspect replica-set topology: $output"
      return 43
      ;;
  esac
}

wait_for_desired_topology() {
  local members_js="$1" rs_name="$2"
  local deadline=$((SECONDS + MONGO_INIT_TIMEOUT_SECONDS)) rc

  while :; do
    if check_topology "$members_js" "$rs_name"; then
      return 0
    else
      rc=$?
    fi

    (( rc == 42 )) && fatal "replica-set topology conflicts with requested configuration"
    (( SECONDS < deadline )) || fatal "replica-set configuration did not converge within ${MONGO_INIT_TIMEOUT_SECONDS}s"
    sleep "$MONGO_READY_INTERVAL_SECONDS"
  done
}

main() {
  validate_uint MONGO_READY_TIMEOUT_SECONDS "$MONGO_READY_TIMEOUT_SECONDS" 1 3600
  validate_uint MONGO_READY_INTERVAL_SECONDS "$MONGO_READY_INTERVAL_SECONDS" 1 60
  validate_uint MONGO_INIT_TIMEOUT_SECONDS "$MONGO_INIT_TIMEOUT_SECONDS" 1 3600
  [[ "$MONGO_RS_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || fatal "MONGO_RS_NAME contains unsupported characters"
  [[ "$MONGO_URI" == mongodb://* || "$MONGO_URI" == mongodb+srv://* ]] || fatal "MONGO_URI must use mongodb:// or mongodb+srv://"

  parse_members "$MONGO_MEMBERS"
  mongo_shell="$(select_shell)"

  wait_ready

  local members_js rs_name rc
  members_js="$(build_members_js)"
  rs_name="$(js_string "$MONGO_RS_NAME")"

  if check_topology "$members_js" "$rs_name"; then
    log "replica set '$MONGO_RS_NAME' already matches requested topology"
    return 0
  else
    rc=$?
  fi

  case "$rc" in
    3)
      log "initiating replica set '$MONGO_RS_NAME'"
      mongo_eval "const result=rs.initiate({_id:\"${rs_name}\",members:[${members_js}]}); if (!result || result.ok !== 1) { printjson(result); quit(1); }" >/dev/null
      wait_for_desired_topology "$members_js" "$rs_name"
      log "replica set '$MONGO_RS_NAME' initialized"
      ;;
    42)
      fatal "replica-set topology conflicts with requested configuration"
      ;;
    *)
      fatal "unable to determine current replica-set state"
      ;;
  esac
}

main "$@"
