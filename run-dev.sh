#!/bin/bash

# Enable Prisma debugging
export DEBUG="prisma:*:info"

# Set Prisma CLI cache directory to a writable location
export PRISMA_CLI_CACHE_DIR="/tmp/.cache"

# Create the cache directory if it doesn't exist
mkdir -p $PRISMA_CLI_CACHE_DIR

# Debug statement to print the password being used
# echo "Using password: $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD"

# Export the client identity file
openssl pkcs12 -password pass:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD -export -out /tmp/client-identity.p12 -inkey $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY -in $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT

# Convert the client identity file to PEM format
openssl pkcs12 -in /tmp/client-identity.p12 -out /tmp/client-identity.pem -nodes -password pass:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD

# Check the contents of the PEM file
openssl x509 -in /tmp/client-identity.pem -text -noout

# Debug statement to print the SSL root certificate path
# echo "SSL Root Certificate Path: $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT"

# Check the SSL connection to the database
openssl s_client -connect $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT -CAfile $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT

# Verify the certificates
openssl verify -CAfile $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT /tmp/client-identity.pem
VERIFY_EXIT_CODE=$?

if [ $VERIFY_EXIT_CODE -eq 0 ]; then
  echo "Certificate verification successful."
else
  echo "Certificate verification failed."
  if [ $VERIFY_EXIT_CODE -eq 20 ]; then
    echo "Error: unable to get local issuer certificate."
  fi
fi

# Check if the root certificate file exists
if [ ! -f "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT" ]; then
  echo "Root certificate file not found at $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT" >> /tmp/run_error.log
fi

# Check if the client identity file exists
if [ ! -f "/tmp/client-identity.p12" ]; then
  echo "Client identity file not found at /tmp/client-identity.p12" >> /tmp/run_error.log
fi

# Set the DATABASE_URL environment variable with proper SSL parameters for Prisma 6
# For GCP Cloud SQL proxy connections, we need to disable SSL verification or use sslmode=disable
# The proxy itself handles encryption, so we can safely disable SSL at the database driver level
export DATABASE_URL="postgresql://$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD@$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT/umami-dev?sslmode=disable" || echo "Failed to set DATABASE_URL" >> /tmp/run_error.log

# Export REDIS_URL for the REDIS instance using the URI and credentials
if [[ -n "$REDIS_USERNAME_UMAMI_DEV" && -n "$REDIS_PASSWORD_UMAMI_DEV" ]]; then
  export REDIS_URL="$(echo $REDIS_URI_UMAMI_DEV | sed "s#://#://$REDIS_USERNAME_UMAMI_DEV:$REDIS_PASSWORD_UMAMI_DEV@#")"
else
  export REDIS_URL="$REDIS_URI_UMAMI_DEV"
fi

# Debug statements to verify environment variables
echo "=== Database Connection Debug Info ==="
echo "DB Host: $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST"
echo "DB Port: $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT"
echo "DB Username: $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME"
echo "DATABASE_URL (first 100 chars): ${DATABASE_URL:0:100}..."
echo "======================================"

PRISMA_EXIT_CODE="${PRISMA_EXIT_CODE:-0}"
if [ "$PRISMA_EXIT_CODE" -ne 0 ]; then
  echo "Failed to connect to the database. See /tmp/prisma_output.log for details." >> /tmp/run_error.log
else
  echo "Successfully pushed Prisma schema to the database." >> /tmp/prisma_output.log
fi

# Ensure DATABASE_URL is available to the Node.js process
export DATABASE_URL

# Start the application
echo "Starting application with pnpm start-docker..."
exec pnpm start-docker
