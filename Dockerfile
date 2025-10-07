FROM ghcr.io/umami-software/umami:postgresql-v2.19.0

USER root
RUN apk update && apk add --no-cache bash openssl ca-certificates postgresql-client libc6-compat

WORKDIR /app

# Set environment variables for Prisma
ENV PRISMA_CLI_QUERY_ENGINE_TYPE=binary
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_SCHEMA_ENGINE_TYPE=binary

# Ensure Prisma engines directory has correct permissions
RUN mkdir -p /app/node_modules/.pnpm/@prisma+engines@6.7.0/node_modules/@prisma/engines && \
    chmod -R 777 /app/node_modules/.pnpm/@prisma+engines@6.7.0/node_modules/@prisma/engines && \
    mkdir -p /app/node_modules/.prisma && \
    chmod -R 777 /app/node_modules/.prisma

# Ensure Next.js directory has correct permissions
RUN mkdir -p /app/.next && \
    chmod -R 777 /app/.next

# Copy all run scripts and set permissions
COPY run.sh /app/run.sh
COPY run-dev.sh /app/run-dev.sh
RUN chmod +x /app/run.sh /app/run-dev.sh

EXPOSE 3000

# Use environment variable to determine which script to run (default to run.sh for backward compatibility)
CMD ["/bin/bash", "-c", "/app/${RUN_SCRIPT:-run.sh}"]