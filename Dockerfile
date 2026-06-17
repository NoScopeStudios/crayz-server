FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG DAYZ_UID=1000
ARG DAYZ_GID=1000

ENV STEAMCMD_ROOT=/opt/steamcmd \
    DAYZ_SERVER_DIR=/dayz/server \
    DAYZ_PROFILE_DIR=/dayz/profiles \
    DAYZ_LOG_DIR=/dayz/logs \
    DAYZ_CONFIG_DIR=/dayz/config

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        gosu \
        lib32gcc-s1 \
        libc6-i386 \
        libstdc++6 \
        tini \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${DAYZ_GID}" dayz \
    && useradd --uid "${DAYZ_UID}" --gid "${DAYZ_GID}" --create-home --shell /bin/bash dayz \
    && mkdir -p "${STEAMCMD_ROOT}" "${DAYZ_SERVER_DIR}" "${DAYZ_PROFILE_DIR}" "${DAYZ_LOG_DIR}" "${DAYZ_CONFIG_DIR}" \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
        | tar -xz -C "${STEAMCMD_ROOT}" \
    && chown -R dayz:dayz "${STEAMCMD_ROOT}" /dayz

COPY --chown=dayz:dayz scripts/entrypoint.sh /usr/local/bin/dayz-entrypoint
COPY --chown=dayz:dayz scripts/update-server.sh /usr/local/bin/dayz-update-server

RUN chmod 0755 /usr/local/bin/dayz-entrypoint /usr/local/bin/dayz-update-server

WORKDIR /dayz/server

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dayz-entrypoint"]
