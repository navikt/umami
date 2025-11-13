#!/bin/bash

# Enable Prisma debugging
export DEBUG="prisma:*:info"

# Set Prisma CLI cache directory to a writable location
export PRISMA_CLI_CACHE_DIR="/tmp/.cache"

# Create the cache directory if it doesn't exist
mkdir -p $PRISMA_CLI_CACHE_DIR

# Create directory for SSL certificates
mkdir -p /tmp/ssl

# Export and convert certificates to PEM format
echo "Converting certificates..."

# Convert client certificate and key to PEM format
cat "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT" > /tmp/ssl/client-cert.pem
cat "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY" > /tmp/ssl/client-key.pem
cat "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT" > /tmp/ssl/ca-cert.pem

# Set proper permissions for key file (PostgreSQL requires this)
chmod 600 /tmp/ssl/client-key.pem

# Verify certificates exist
if [ ! -f "/tmp/ssl/ca-cert.pem" ]; then
    echo "Root certificate file not found" >> /tmp/run_error.log
    exit 1
fi

if [ ! -f "/tmp/ssl/client-cert.pem" ]; then
    echo "Client certificate file not found" >> /tmp/run_error.log
    exit 1
fi

# Test SSL connection
echo "Testing SSL connection..."
openssl s_client -connect $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT \
    -CAfile /tmp/ssl/ca-cert.pem \
    -cert /tmp/ssl/client-cert.pem \
    -key /tmp/ssl/client-key.pem \
    -showcerts < /dev/null

# Verify the certificates
openssl verify -CAfile /tmp/ssl/ca-cert.pem /tmp/ssl/client-cert.pem
VERIFY_EXIT_CODE=$?

if [ $VERIFY_EXIT_CODE -eq 0 ]; then
    echo "Certificate verification successful."
else
    echo "Certificate verification failed with exit code: $VERIFY_EXIT_CODE"
    if [ $VERIFY_EXIT_CODE -eq 20 ]; then
        echo "Error: unable to get local issuer certificate."
    fi
fi

# Set PostgreSQL SSL environment variables (standard approach for Prisma 6.16.0+)
export PGSSLMODE=verify-full
export PGSSLCERT=/tmp/ssl/client-cert.pem
export PGSSLKEY=/tmp/ssl/client-key.pem
export PGSSLROOTCERT=/tmp/ssl/ca-cert.pem

# Set the DATABASE_URL with standard SSL parameters
export DATABASE_URL="postgresql://$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD@$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT/umami-dev?sslmode=verify-full&sslcert=/tmp/ssl/client-cert.pem&sslkey=/tmp/ssl/client-key.pem&sslrootcert=/tmp/ssl/ca-cert.pem"

# Export REDIS_URL for the REDIS instance using the URI and credentials
if [[ -n "$REDIS_USERNAME_UMAMI_DEV" && -n "$REDIS_PASSWORD_UMAMI_DEV" ]]; then
    export REDIS_URL="$(echo $REDIS_URI_UMAMI_DEV | sed "s#://#://$REDIS_USERNAME_UMAMI_DEV:$REDIS_PASSWORD_UMAMI_DEV@#")"
else
    export REDIS_URL="$REDIS_URI_UMAMI_DEV"
fi

# Debug statement to print the DATABASE_URL (with password masked)
echo "DATABASE_URL: $(echo $DATABASE_URL | sed 's/:[^:]*@/:****@/')"

# Test database connection
echo "Testing database connection..."
psql "$DATABASE_URL" -c "SELECT version();" || echo "Database connection test failed" >> /tmp/run_error.log

# Start the application
echo "Starting application..."
yarn start-docker