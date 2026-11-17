# syntax=docker/dockerfile:1
# Dedicated server image. Expects the exported server in ./server/ next to
# this file (CI copies build/server/ here before building).
FROM debian:bookworm-slim

ARG VERSION=dev
LABEL org.opencontainers.image.title="Experiment Undead server" \
      org.opencontainers.image.version="${VERSION}"

RUN useradd --uid 1000 --create-home --home-dir /home/server server \
    && mkdir -p /data \
    && chown server:server /data

# Engine binary first: it only changes with the Godot version, so this layer
# is shared between game versions and Unraid only downloads the small .pck.
COPY --chown=server:server --chmod=755 server/ExperimentUndead-server.x86_64 /opt/server/
COPY --chown=server:server --chmod=755 entrypoint.sh /opt/server/
COPY --chown=server:server server/ExperimentUndead-server.pck /opt/server/

ENV EU_PORT=7777 \
    EU_MAX_PLAYERS=8 \
    EU_STOP_FILE=/tmp/eu_stop \
    EU_READY_FILE=/tmp/eu_ready \
    XDG_DATA_HOME=/data

USER server
WORKDIR /opt/server
VOLUME ["/data"]
EXPOSE 7777/udp 8777/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD test -f /tmp/eu_ready

ENTRYPOINT ["/opt/server/entrypoint.sh"]
