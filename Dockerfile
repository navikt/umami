# Install dependencies only when needed
FROM cgr.dev/chainguard/wolfi-base@sha256:77891a12dc762228955294f2207ee1cbd2b127f18dc7c7458203116288dce828 AS deps

USER root

RUN apk add --no-cache nodejs npm git

WORKDIR /app

# Clone Umami source at specific version
RUN git clone --depth 1 --branch v3.0.0 https://github.com/umami-software/umami.git . && \
    npm install -g pnpm && \
    pnpm install --frozen-lockfile

# Rebuild the source code only when needed
FROM cgr.dev/chainguard/wolfi-base@sha256:77891a12dc762228955294f2207ee1cbd2b127f18dc7c7458203116288dce828 AS builder

USER root

RUN apk add --no-cache nodejs npm

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json /app/pnpm-lock.yaml ./
COPY --from=deps /app/public ./public
COPY --from=deps /app/src ./src
COPY --from=deps /app/prisma ./prisma
COPY --from=deps /app/scripts ./scripts
COPY --from=deps /app/next.config.ts ./next.config.ts
COPY --from=deps /app/tsconfig.json ./tsconfig.json
COPY --from=deps /app/rollup.tracker.config.js ./rollup.tracker.config.js

ARG DATABASE_TYPE
ARG BASE_PATH

ENV DATABASE_TYPE=$DATABASE_TYPE
ENV BASE_PATH=$BASE_PATH
ENV NEXT_TELEMETRY_DISABLED=1
# Set Node options to limit memory usage
ENV NODE_OPTIONS="--max-old-space-size=3072"

# Install pnpm and run build with standard webpack (not turbo)
RUN npm install -g pnpm && \
    pnpm run build-docker

# Production image, copy all the files and run next
FROM cgr.dev/chainguard/wolfi-base@sha256:77891a12dc762228955294f2207ee1cbd2b127f18dc7c7458203116288dce828 AS runner

USER root

RUN apk add --no-cache nodejs npm bash openssl ca-certificates postgresql-client curl

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    npm install -g pnpm

# Script dependencies
RUN pnpm add npm-run-all dotenv chalk semver prisma@6.18.0 @prisma/adapter-pg@6.18.0

# Permissions for prisma
RUN chown -R nextjs:nodejs node_modules/.pnpm/ || true

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/generated ./generated

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy custom run scripts
COPY --chown=nextjs:nodejs run.sh /app/run.sh
COPY --chown=nextjs:nodejs run-dev.sh /app/run-dev.sh
RUN chmod +x /app/run.sh /app/run-dev.sh

USER nextjs

EXPOSE 3000

ENV HOSTNAME=0.0.0.0
ENV PORT=3000

# Use environment variable to determine which script to run (default to custom run.sh)
CMD ["/bin/bash", "-c", "/app/${RUN_SCRIPT:-run.sh}"]
