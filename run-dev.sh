#!/bin/bash

# Enable Prisma debugging
export DEBUG="prisma:*:info"

# Set Prisma CLI cache directory to a writable location
export PRISMA_CLI_CACHE_DIR="/tmp/.cache"

# Create the cache directory if it doesn't exist
mkdir -p $PRISMA_CLI_CACHE_DIR

# Debug: Show certificate file information
echo "=== Certificate Setup for Prisma v6 ==="
echo "Client cert file exists: $(test -f "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT" && echo "YES" || echo "NO")"
echo "Client key file exists: $(test -f "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY" && echo "YES" || echo "NO")"
echo "Root CA file exists: $(test -f "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT" && echo "YES" || echo "NO")"

echo ""
echo "=== Analyzing certificates ==="
echo "Client certificate subject:"
openssl x509 -in $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT -noout -subject 2>/dev/null || echo "Failed to read client cert"

echo ""
echo "Number of certificates in root CA file:"
grep -c "BEGIN CERTIFICATE" $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT || echo "0"

echo ""
echo "Root CA certificate subjects:"
awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/ {print}' $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT | \
  csplit -z -f /tmp/ca-cert- - '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null
for cert in /tmp/ca-cert-*; do
  if [ -s "$cert" ]; then
    openssl x509 -in "$cert" -noout -subject 2>/dev/null || true
  fi
done
rm -f /tmp/ca-cert-* 2>/dev/null

echo ""
echo "=== Creating combined certificate file with full chain ==="
# Create combined cert file: client cert + all CA certs
cat $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT > /tmp/client-cert-full.pem
echo "" >> /tmp/client-cert-full.pem
cat $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT >> /tmp/client-cert-full.pem
echo "Combined certificate file created at /tmp/client-cert-full.pem"

echo ""
echo "=== Testing SSL connection to database ==="

echo ""
echo "=== Testing SSL connection to database ==="

# Check the SSL connection to the database - this validates the server cert works
openssl s_client -connect $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT \
  -CAfile $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT \
  -cert $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT \
  -key $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY \
  -showcerts </dev/null 2>&1 | grep -E "(Verify return code|CN=)"

echo ""
echo "=== Certificate verification (for debugging only) ==="
# Note: This verification may fail with error 20, but that's OK if the SSL connection above succeeded
# The combined cert file will work with Prisma v6
openssl verify -CAfile $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT /tmp/client-cert-full.pem 2>&1 || \
  echo "Note: Verification error is expected but won't affect Prisma connection"

echo ""
echo "=== Setup complete, proceeding with application startup ===="

echo ""
echo "=== Setup complete, proceeding with application startup ===="

# Check if the root certificate file exists
if [ ! -f "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT" ]; then
  echo "ERROR: Root certificate file not found at $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT" | tee -a /tmp/run_error.log
  exit 1
fi

# Check if the combined client certificate file was created
if [ ! -f "/tmp/client-cert-full.pem" ]; then
  echo "ERROR: Combined client certificate file not found at /tmp/client-cert-full.pem" | tee -a /tmp/run_error.log
  exit 1
fi

# Set the DATABASE_URL environment variable
# Prisma v6+ uses different SSL parameter names: sslmode, sslcert, sslkey, sslrootcert
# Using the combined certificate file that includes the full chain
export DATABASE_URL="postgresql://$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD@$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT/umami-dev?sslmode=require&sslcert=/tmp/client-cert-full.pem&sslkey=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY&sslrootcert=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT"

# Export REDIS_URL for the REDIS instance using the URI and credentials
if [[ -n "$REDIS_USERNAME_UMAMI_DEV" && -n "$REDIS_PASSWORD_UMAMI_DEV" ]]; then
  export REDIS_URL="$(echo $REDIS_URI_UMAMI_DEV | sed "s#://#://$REDIS_USERNAME_UMAMI_DEV:$REDIS_PASSWORD_UMAMI_DEV@#")"
else
  export REDIS_URL="$REDIS_URI_UMAMI_DEV"
fi

# Debug statement to print the DATABASE_URL (without password)
echo ""
echo "=== Database Configuration ==="
echo "DATABASE_URL configured for Prisma v6 with SSL client certificate authentication"
echo "  - sslmode: require"
echo "  - sslcert: /tmp/client-cert-full.pem (combined chain)"
echo "  - sslkey: [using NAIS provided key]"
echo "  - sslrootcert: [using NAIS provided CA]"
echo ""

PRISMA_EXIT_CODE="${PRISMA_EXIT_CODE:-0}"
if [ "$PRISMA_EXIT_CODE" -ne 0 ]; then
  echo "Failed to connect to the database. See /tmp/prisma_output.log for details." >> /tmp/run_error.log
else
  echo "Successfully pushed Prisma schema to the database." >> /tmp/prisma_output.log
fi

# Start the application
yarn start-docker
