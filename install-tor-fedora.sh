#!/usr/bin/env bash
# Install Tor on Fedora and run it as an EXIT relay in the foreground
# (container-friendly: no systemd, logs stream to stdout).
#
# https://community.torproject.org/relay/setup/exit/

set -Eeuo pipefail

# --- logging helpers ---------------------------------------------------------
log() { printf '%(%Y-%m-%dT%H:%M:%S%z)T [run] %s\n' -1 "$*"; }
die() { printf '%(%Y-%m-%dT%H:%M:%S%z)T [run] ERROR: %s\n' -1 "$*" >&2; exit 1; }
trap 'die "failed at line ${LINENO} (exit $?)"' ERR

# `docker run -e DEBUG=1 ...` turns on full command tracing.
[ "${DEBUG:-0}" = "1" ] && set -x

TORRC=/etc/tor/torrc

log "Starting setup on $(uname -srm)"

[ "$EUID" -eq 0 ] || die "This script must run as root."
log "Running as root (uid=${EUID}) — OK"

log "Installing Tor from Fedora repositories..."
dnf install -y tor
log "Installed version:"
tor --version | sed 's/^/    /'

log "Writing EXIT relay configuration to ${TORRC} (reduced policy)..."
cat > "$TORRC" <<'EOF'
# Tor EXIT relay configuration
Nickname YourRelayNickname
ContactInfo your-email@example.org

# Relay port (must be published + publicly reachable: docker run -p 9001:9001)
ORPort 9001

ExitRelay 1
IPv6Exit 0
ExitPolicy accept *:20-21, accept *:22, accept *:23, accept *:43, accept *:53, accept *:79-81, accept *:88, accept *:110, accept *:143, accept *:194, accept *:220, accept *:389, accept *:443
ExitPolicy accept *:464, accept *:465, accept *:531, accept *:543-544, accept *:554, accept *:563, accept *:587, accept *:636, accept *:706, accept *:749, accept *:873, accept *:902-904, accept *:981, accept *:989-995
ExitPolicy accept *:1194, accept *:1220, accept *:1293, accept *:1500, accept *:1533, accept *:1677, accept *:1723, accept *:1755, accept *:1863, accept *:2082-2083, accept *:2086-2087, accept *:2095-2096, accept *:2102-2104
ExitPolicy accept *:3128, accept *:3389, accept *:3690, accept *:4321, accept *:4643, accept *:5050, accept *:5190, accept *:5222-5223, accept *:5228, accept *:5900, accept *:6660-6669, accept *:6679, accept *:6697
ExitPolicy accept *:8000, accept *:8008, accept *:8074, accept *:8080, accept *:8082, accept *:8087-8088, accept *:8232-8233, accept *:8332-8333, accept *:8443, accept *:8888, accept *:9418, accept *:9999, accept *:11371, accept *:19294, accept *:19638, accept *:50002, accept *:64738
ExitPolicy reject *:*

SocksPort 0

# Stream logs to stdout so `docker logs` shows them.
# Bump to `Log info stdout` (or debug) for much more detail.
Log notice stdout
EOF
log "Config written (${TORRC}, $(wc -l < "$TORRC") lines)"

log "Validating configuration..."
tor --verify-config -f "$TORRC"
log "Configuration is valid."

log "Effective relay settings:"
grep -E '^(Nickname|ContactInfo|ORPort|ExitRelay|IPv6Exit|SocksPort|Log)\b' "$TORRC" | sed 's/^/    /' || true

log "Starting Tor in the foreground — watch for 'Bootstrapped 100% (done)' below."
log "(Ctrl-C to stop.)"

# exec => tor becomes PID 1, receives signals, and its logs go to docker logs
exec tor -f "$TORRC"

