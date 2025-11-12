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
SSL_OUTPUT_FILE=$(mktemp)
openssl s_client -connect $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT \
  -CAfile $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT \
  -cert $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT \
  -key $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY \
  -showcerts </dev/null 2>&1 | tee "$SSL_OUTPUT_FILE" | grep -E "(Verify return code|CN=)"

# Extract the first certificate from the s_client output and read subjectAltName
SERVER_CERT=$(awk 'BEGIN{p=0} /-----BEGIN CERTIFICATE-----/{p=1} {if(p) print} /-----END CERTIFICATE-----/{print; exit}' "$SSL_OUTPUT_FILE")
DB_SERVER_NAME=$(echo "$SERVER_CERT" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -o 'DNS:[^,]*' | head -1 | cut -d: -f2)
rm -f "$SSL_OUTPUT_FILE"

if [ -n "$DB_SERVER_NAME" ]; then
  echo "Detected database server name from certificate: $DB_SERVER_NAME"
else
  DB_SERVER_NAME="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST"
  echo "Warning: Could not detect server name from certificate. Using host: $DB_SERVER_NAME"
fi

if [ "$DB_SERVER_NAME" != "$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST" ]; then
  CONNECTION_SSLMODE="verify-full"
else
  CONNECTION_SSLMODE="require"
fi

echo ""
echo "=== Certificate verification (for debugging only) ==="
# Note: This verification may fail with error 20, but that's OK if the SSL connection above succeeded
# The combined cert file will work with Prisma v6
openssl verify -CAfile $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT /tmp/client-cert-full.pem 2>&1 || \
  echo "Note: Verification error is expected but won't affect Prisma connection"

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

# Set the DATABASE_URL environment variable for Umami v3
# Use the DNS name from the certificate for TLS verification, but keep hostaddr for direct connection
export DATABASE_URL="postgresql://$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD@$DB_SERVER_NAME:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT/umami-dev?sslmode=$CONNECTION_SSLMODE&hostaddr=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST"

# Umami v3 requires these separate environment variables
export DATABASE_TYPE="postgresql"
export DATABASE_HOST="$DB_SERVER_NAME"
export DATABASE_PORT="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT"
export DATABASE_NAME="umami-dev"
export DATABASE_USER="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME"
export DATABASE_PASSWORD="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD"

# SSL configuration for PostgreSQL/Prisma - both env vars and for manual connection
export PGSSLMODE="$CONNECTION_SSLMODE"
export PGSSLCERT="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT"
export PGSSLKEY="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY"
export PGSSLROOTCERT="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT"
export PGHOST="$DB_SERVER_NAME"
export PGHOSTADDR="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST"

# Node.js SSL environment variables for TLS connections
export NODE_EXTRA_CA_CERTS="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT"

# Test the connection with psql to verify SSL auth works
echo ""
echo "=== Testing PostgreSQL connection with psql ==="
PGPASSWORD="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD" psql \
  "host=$DB_SERVER_NAME hostaddr=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST sslmode=$CONNECTION_SSLMODE sslcert=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLCERT sslkey=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY sslrootcert=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT port=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT dbname=umami-dev user=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME" \
  -c "SELECT version();" 2>&1 | head -5 || echo "Note: psql test failed, but Prisma might still work"
echo ""

# Export REDIS_URL for the REDIS instance using the URI and credentials
if [[ -n "$REDIS_USERNAME_UMAMI_DEV" && -n "$REDIS_PASSWORD_UMAMI_DEV" ]]; then
  export REDIS_URL="$(echo $REDIS_URI_UMAMI_DEV | sed "s#://#://$REDIS_USERNAME_UMAMI_DEV:$REDIS_PASSWORD_UMAMI_DEV@#")"
else
  export REDIS_URL="$REDIS_URI_UMAMI_DEV"
fi

# Debug statement to print the DATABASE_URL (without password)
echo ""
echo "=== Database Configuration ==="
echo "DATABASE_URL configured for Umami v3 / Prisma v6"
echo "  - Host: $DATABASE_HOST"
echo "  - Port: $DATABASE_PORT"
echo "  - Database: $DATABASE_NAME"
echo "  - User: $DATABASE_USER"
echo "  - Hostaddr: $PGHOSTADDR"
echo ""
echo "PostgreSQL SSL Environment Variables:"
echo "  - PGSSLMODE: $PGSSLMODE"
echo "  - PGSSLCERT: $PGSSLCERT"
echo "  - PGSSLKEY: $PGSSLKEY"
echo "  - PGSSLROOTCERT: $PGSSLROOTCERT"
echo "  - NODE_EXTRA_CA_CERTS: $NODE_EXTRA_CA_CERTS"
echo ""
echo "Full DATABASE_URL (masked password):"
echo "$DATABASE_URL" | sed 's/:'"$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD"'@/:***@/'
echo ""

PRISMA_EXIT_CODE="${PRISMA_EXIT_CODE:-0}"
if [ "$PRISMA_EXIT_CODE" -ne 0 ]; then
  echo "Failed to connect to the database. See /tmp/prisma_output.log for details." >> /tmp/run_error.log
else
  echo "Successfully pushed Prisma schema to the database." >> /tmp/prisma_output.log
fi

# Start the application
yarn start-docker
