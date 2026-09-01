# Folding@home v8 client, headless, in a container.
#
# The official project ships no container image and no Fedora repo, only
# per-platform packages. We install the upstream x86_64 RPM (which also carries
# the Linux FahCore binaries' dependencies) and drive the client's websocket
# control API to switch it out of its default paused state into folding.
FROM fedora:44

# Pin the client version. Override at build time:
#   podman build --build-arg FAH_VERSION=8.5.6 ...
ARG FAH_VERSION=8.5.6
ARG FAH_RPM_URL=https://download.foldingathome.org/releases/public/fah-client/debian-10-64bit/release/fah_client-${FAH_VERSION}-1.x86_64.rpm

# dnf resolves the RPM's runtime deps (expat, systemd-libs, lz4, zlib,
# polkit, procps, shadow-utils). python3-websocket-client is required by the
# bundled `fahctl` control CLI. ca-certificates for TLS to the work servers.
RUN dnf install -y --setopt=install_weak_deps=False \
        "${FAH_RPM_URL}" \
        python3-websocket-client \
        ca-certificates \
        bash \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Work/data directory. The client writes WU state, cores and logs to its CWD.
# Owned by the unprivileged fah-client user created by the RPM.
RUN mkdir -p /fah && chown fah-client:fah-client /fah
WORKDIR /fah

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Web Control / API. Publish to the host with:  -p 127.0.0.1:7396:7396
EXPOSE 7396

# Folding identity / tuning (all optional). See entrypoint.sh.
ENV FAH_USER=Anonymous \
    FAH_TEAM=0 \
    FAH_PASSKEY="" \
    FAH_MACHINE_NAME="" \
    FAH_ACCOUNT_TOKEN="" \
    FAH_CPUS="" \
    FAH_CAUSE=any \
    FAH_HTTP=0.0.0.0:7396 \
    FAH_ALLOW=0/0 \
    FAH_EXTRA_ARGS=""

USER fah-client
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
