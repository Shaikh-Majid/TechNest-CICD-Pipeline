# syntax=docker/dockerfile:1.7

# ============================================================================
# TechNest Auth App — production image
#
# Node.js/Express app using node-oracledb 5.5.0, which is THICK-MODE ONLY
# (thin mode landed in oracledb 6.x). That means the Oracle Instant Client
# native libraries must be present on the runtime image and on LD_LIBRARY_PATH
# for oracledb to load at all — this is not optional. Alpine/musl is not used
# as the base for this reason: Oracle only ships glibc builds of Instant
# Client, and getting them working under musl is not worth the maintenance
# burden versus a slim Debian base.
# ============================================================================

ARG NODE_VERSION=22-bookworm-slim

# ----------------------------------------------------------------------------
# Stage 1: install production node_modules in isolation
# (kept separate from the source COPY so this layer only rebuilds when
# package*.json actually changes)
# ----------------------------------------------------------------------------
FROM node:${NODE_VERSION} AS deps

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev --no-audit --no-fund

# ----------------------------------------------------------------------------
# Stage 2: runtime
# ----------------------------------------------------------------------------
FROM node:${NODE_VERSION} AS runtime

# Pin the Oracle Instant Client release explicitly rather than tracking
# "latest" — Oracle reorganizes/retires old downloads, so bumping this is a
# deliberate version change, not an implicit one.
# For air-gapped/reproducible builds, mirror this zip into an internal
# artifact store and point OIC_BASE_URL at it via --build-arg instead of
# pulling from download.oracle.com at build time.
ARG OIC_VERSION=21.13.0.0.0
ARG OIC_VERSION_PATH=213000
ARG OIC_BASE_URL=https://download.oracle.com/otn_software/linux/instantclient/${OIC_VERSION_PATH}
ARG OIC_DIR=instantclient_21_13

RUN apt-get update && apt-get install -y --no-install-recommends \
        libaio1 \
        wget \
        unzip \
        ca-certificates \
        tini \
    && wget -q "${OIC_BASE_URL}/instantclient-basiclite-linux.x64-${OIC_VERSION}dbru.zip" -O /tmp/instantclient.zip \
    && unzip -q /tmp/instantclient.zip -d /opt/oracle \
    && rm -f /tmp/instantclient.zip \
    && rm -f /opt/oracle/${OIC_DIR}/*jdbc* /opt/oracle/${OIC_DIR}/*occi* \
             /opt/oracle/${OIC_DIR}/*mysql* /opt/oracle/${OIC_DIR}/*README \
             /opt/oracle/${OIC_DIR}/*.jar \
    && echo "/opt/oracle/${OIC_DIR}" > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig \
    && apt-get purge -y --auto-remove wget unzip \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production \
    PORT=3000 \
    LD_LIBRARY_PATH=/opt/oracle/${OIC_DIR} \
    NPM_CONFIG_UPDATE_NOTIFIER=false

WORKDIR /app

# Non-root runtime user — the base node image ships a "node" user (uid 1000)
# but we pin our own to be explicit and avoid relying on upstream defaults.
RUN groupadd --gid 1001 nodejs \
    && useradd --uid 1001 --gid nodejs --shell /usr/sbin/nologin --no-create-home nodejs

COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs package.json ./
COPY --chown=nodejs:nodejs server.js ./
COPY --chown=nodejs:nodejs config ./config
COPY --chown=nodejs:nodejs middleware ./middleware
COPY --chown=nodejs:nodejs routes ./routes
COPY --chown=nodejs:nodejs public ./public

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD node -e "require('http').get({host:'127.0.0.1',port:process.env.PORT||3000,path:'/api/health',timeout:4000}, r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

# tini as PID 1 for correct signal forwarding (SIGTERM on `docker stop`) and
# zombie reaping — Node does not do either of these on its own as PID 1.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
