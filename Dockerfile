# Tor exit relay, containerised. Debian base + Debian's packaged tor.
#
# Runs an exit relay in the foreground, config generated from environment
# variables by the entrypoint. Tor drops privileges to the debian-tor user.
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      tor \
      tor-geoipdb \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# torrc is generated at runtime from env; keep DataDirectory on a volume.
RUN mkdir -p /var/lib/tor && chown -R debian-tor:debian-tor /var/lib/tor \
 && chmod 700 /var/lib/tor

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ORPort (relay traffic). Publish this to the internet on your dedicated IP.
EXPOSE 9001

# --- Relay configuration (see entrypoint.sh) ---------------------------------
ENV TOR_NICKNAME="torexit" \
    TOR_CONTACT="" \
    TOR_ORPORT="9001" \
    TOR_DIRPORT="0" \
    TOR_EXIT_POLICY="reduced" \
    TOR_IPV6_EXIT="0" \
    TOR_BANDWIDTH_RATE="" \
    TOR_BANDWIDTH_BURST="" \
    TOR_ACCOUNTING_MAX="" \
    TOR_EXTRA=""

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
