FROM ghcr.io/umami-software/umami:3.0.2
USER root

RUN apk update && apk add --no-cache bash openssl ca-certificates postgresql-client libc6-compat

WORKDIR /app

# Ensure .prisma directory has correct permissions (still needed for generated client)
RUN mkdir -p /app/node_modules/.prisma && \
    chmod -R 777 /app/node_modules/.prisma

# Ensure Next.js directory has correct permissions
RUN mkdir -p /app/.next && \
    chmod -R 777 /app/.next

EXPOSE 3000

# Default command can be overridden by nais.yaml command/args
CMD ["yarn", "start-docker"]
