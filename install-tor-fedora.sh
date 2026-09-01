#!/usr/bin/env bash
# Install Tor on Fedora and configure it as an EXIT relay.
#
# This follows the official Tor Project documentation:
# https://community.torproject.org/relay/setup/bridge/fedora-rhel/

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must run as root." >&2
  exit 1
fi

echo "[*] Installing Tor from Fedora repositories..."
dnf install -y tor

echo "[*] Enabling Tor service..."
systemctl enable tor

echo "[*] Creating EXIT relay configuration with reduced policy..."
cat > /etc/tor/torrc <<'EOF'
# Tor EXIT relay configuration
# Edit ContactInfo and Nickname, then: systemctl restart tor

Nickname YourRelayNickname
ContactInfo your-email@example.org

# Relay port (must be reachable from the internet)
ORPort 9001

# Exit relay with REDUCED exit policy (Tor Project recommended)
# Allows common ports, blocks the high-abuse ones (SMTP, file-sharing, etc.)
ExitRelay 1
IPv6Exit 0
ExitPolicy accept *:20-21, accept *:22, accept *:23, accept *:43, accept *:53, accept *:79-81, accept *:88, accept *:110, accept *:143, accept *:194, accept *:220, accept *:389, accept *:443
ExitPolicy accept *:464, accept *:465, accept *:531, accept *:543-544, accept *:554, accept *:563, accept *:587, accept *:636, accept *:706, accept *:749, accept *:873, accept *:902-904, accept *:981, accept *:989-995
ExitPolicy accept *:1194, accept *:1220, accept *:1293, accept *:1500, accept *:1533, accept *:1677, accept *:1723, accept *:1755, accept *:1863, accept *:2082-2083, accept *:2086-2087, accept *:2095-2096, accept *:2102-2104
ExitPolicy accept *:3128, accept *:3389, accept *:3690, accept *:4321, accept *:4643, accept *:5050, accept *:5190, accept *:5222-5223, accept *:5228, accept *:5900, accept *:6660-6669, accept *:6679, accept *:6697
ExitPolicy accept *:8000, accept *:8008, accept *:8074, accept *:8080, accept *:8082, accept *:8087-8088, accept *:8232-8233, accept *:8332-8333, accept *:8443, accept *:8888, accept *:9418, accept *:9999, accept *:11371, accept *:19294, accept *:19638, accept *:50002, accept *:64738
ExitPolicy reject *:*

# To run as a MIDDLE relay instead (no exit traffic, safer):
# ExitRelay 0
# ExitPolicy reject *:*

# Bandwidth limits (optional)
# RelayBandwidthRate 10 MBytes
# RelayBandwidthBurst 20 MBytes

# Accounting limits (optional)
# AccountingMax 500 GBytes
# AccountingStart month 1 00:00

SocksPort 0
Log notice file /var/log/tor/notices.log
EOF

echo "[*] Configuration written to /etc/tor/torrc"
echo ""
echo "⚠️  EXIT RELAY CONFIGURED - READ THIS:"
echo ""
echo "Exit traffic will appear to come from YOUR IP. You WILL receive abuse"
echo "complaints. Run this ONLY on:"
echo "  - A dedicated public IP"
echo "  - A provider that explicitly permits Tor exits"
echo "  - NEVER on home internet or employer/corporate networks"
echo ""
echo "REQUIRED before starting:"
echo "  1. Edit /etc/tor/torrc - set Nickname and ContactInfo"
echo "  2. Set up reverse DNS pointing to this IP"
echo "  3. Monitor the ContactInfo email address for abuse reports"
echo ""
echo "Then start: systemctl start tor"
echo "Check logs: journalctl -u tor -f"
