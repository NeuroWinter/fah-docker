#!/usr/bin/env bash
# Entrypoint for the Folding@home v8 client container.
#
# The v8 client boots into a *paused* state and does no work until told to
# fold. There is no config flag for the run state; it is set over the client's
# local websocket control API. So we:
#   1. start fah-client (logging to /fah/log.txt, persisted in the data volume),
#   2. stream that log file to the container's stdout so `docker logs` works
#      (the client full-buffers its own screen output when stdout is a pipe),
#   3. run a helper that waits for the control port then issues `fahctl fold`,
#   4. forward SIGTERM/SIGINT to the client for a clean, checkpointed shutdown.
# Running under bash as PID 1 means bash reaps the short-lived helpers.
set -euo pipefail

LOG=/fah/log.txt

# --- Build client arguments from environment ---------------------------------
args=(
  --config=/fah/config.xml
  --log-to-screen=false
  --log="${LOG}"
  --log-color=false
  "--http-addresses=${FAH_HTTP}"
  "--allow=${FAH_ALLOW}"
  "--user=${FAH_USER}"
  "--team=${FAH_TEAM}"
  "--cause=${FAH_CAUSE}"
)

[ -n "${FAH_PASSKEY}" ]       && args+=("--passkey=${FAH_PASSKEY}")
[ -n "${FAH_MACHINE_NAME}" ]  && args+=("--machine-name=${FAH_MACHINE_NAME}")
[ -n "${FAH_ACCOUNT_TOKEN}" ] && args+=("--account-token=${FAH_ACCOUNT_TOKEN}")
[ -n "${FAH_CPUS}" ]          && args+=("--cpus=${FAH_CPUS}")

# Split any extra free-form args (word-splitting is intentional here).
if [ -n "${FAH_EXTRA_ARGS}" ]; then
  # shellcheck disable=SC2206
  extra=(${FAH_EXTRA_ARGS})
  args+=("${extra[@]}")
fi

# The control port is always reachable on loopback for fahctl, regardless of
# the advertised bind address in FAH_HTTP.
CTL_HOST=127.0.0.1
CTL_PORT="${FAH_HTTP##*:}"
[ "${CTL_PORT}" = "${FAH_HTTP}" ] && CTL_PORT=7396

# --- Background helper: enable folding once the API is up --------------------
enable_folding() {
  local i
  for i in $(seq 1 120); do
    if (exec 3<>"/dev/tcp/${CTL_HOST}/${CTL_PORT}") 2>/dev/null; then
      exec 3>&- 3<&- 2>/dev/null || true
      if fahctl -a "${CTL_HOST}:${CTL_PORT}" fold >/dev/null 2>&1; then
        echo "[entrypoint] folding enabled via control API"
        return 0
      fi
    fi
    sleep 1
  done
  echo "[entrypoint] WARNING: could not reach control API to enable folding" >&2
}

# --- Launch ------------------------------------------------------------------
# Fresh log each run so the tail below starts clean; the client rotates old
# logs into /fah/logs/ itself.
: > "${LOG}"
tail -n +1 -F "${LOG}" &
TAIL_PID=$!

echo "[entrypoint] starting fah-client ${args[*]}"
fah-client "${args[@]}" &
CLIENT_PID=$!

enable_folding &

# Forward termination to the client so it checkpoints the current work unit.
term() { kill -TERM "${CLIENT_PID}" 2>/dev/null || true; }
trap term TERM INT

# Wait for the client; `wait` returns early on trapped signals, so loop until
# the process is actually gone, then propagate its exit status.
while kill -0 "${CLIENT_PID}" 2>/dev/null; do
  wait "${CLIENT_PID}" && ec=$? || ec=$?
done
kill "${TAIL_PID}" 2>/dev/null || true
exit "${ec:-0}"
