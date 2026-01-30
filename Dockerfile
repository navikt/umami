# Install dependencies only when needed
FROM cgr.dev/chainguard/wolfi-base@sha256:17ab0709456ce1a2aedd85e95f72e58d73133bb70c33ae945a4d4b2424e984f1 AS deps

USER root

RUN apk add --no-cache nodejs npm git

WORKDIR /app

# Clone Umami source at specific version
RUN git clone --depth 1 --branch v3.0.3 https://github.com/umami-software/umami.git . && \
    npm install -g pnpm && \
    pnpm install --frozen-lockfile

# Rebuild the source code only when needed
FROM cgr.dev/chainguard/wolfi-base@sha256:17ab0709456ce1a2aedd85e95f72e58d73133bb70c33ae945a4d4b2424e984f1 AS builder

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
# Set dummy values for build-time to prevent URL construction errors
# These will be overridden at runtime
ENV DATABASE_URL=postgresql://user:pass@localhost:5432/umami
ENV CLICKHOUSE_URL=http://localhost:8123/default
ENV KAFKA_URL=kafka://localhost:9092

RUN npm install -g pnpm && \
    pnpm run build-docker

# Production image, copy all the files and run next
FROM cgr.dev/chainguard/wolfi-base@sha256:17ab0709456ce1a2aedd85e95f72e58d73133bb70c33ae945a4d4b2424e984f1 AS runner

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

USER nextjs

EXPOSE 3000

ENV HOSTNAME=0.0.0.0
ENV PORT=3000

CMD ["pnpm", "start-docker"]
