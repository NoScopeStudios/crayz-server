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

RUN set -eux; \
    if ! getent group dayz >/dev/null; then \
        if getent group | grep -q "^[^:]*:[^:]*:${DAYZ_GID}:"; then \
            groupadd dayz; \
        else \
            groupadd --gid "${DAYZ_GID}" dayz; \
        fi; \
    fi; \
    if ! id -u dayz >/dev/null 2>&1; then \
        if getent passwd | grep -q "^[^:]*:[^:]*:${DAYZ_UID}:"; then \
            useradd --gid dayz --create-home --shell /bin/bash dayz; \
        else \
            useradd --uid "${DAYZ_UID}" --gid dayz --create-home --shell /bin/bash dayz; \
        fi; \
    fi; \
    mkdir -p /home/dayz "${STEAMCMD_ROOT}" "${DAYZ_SERVER_DIR}" "${DAYZ_PROFILE_DIR}" "${DAYZ_LOG_DIR}" "${DAYZ_CONFIG_DIR}" \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
        | tar -xz -C "${STEAMCMD_ROOT}" \
    && chown -R dayz:dayz /home/dayz "${STEAMCMD_ROOT}" /dayz

COPY --chown=dayz:dayz scripts/entrypoint.sh /usr/local/bin/dayz-entrypoint
COPY --chown=dayz:dayz scripts/update-server.sh /usr/local/bin/dayz-update-server

RUN chmod 0755 /usr/local/bin/dayz-entrypoint /usr/local/bin/dayz-update-server

WORKDIR /dayz/server

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dayz-entrypoint"]
