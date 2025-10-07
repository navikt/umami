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

# Set the DATABASE_URL environment variable
export DATABASE_URL="postgresql://$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_USERNAME:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD@$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST:$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PORT/umami-one?sslidentity=/tmp/client-identity.p12&sslpassword=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD&sslcert=$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLROOTCERT" || echo "Failed to set DATABASE_URL" >> /tmp/run_error.log

# Export REDIS_URL for the REDIS instance using the URI and credentials
if [[ -n "$REDIS_USERNAME_UMAMI_DEV" && -n "$REDIS_PASSWORD_UMAMI_DEV" ]]; then
  export REDIS_URL="$(echo $REDIS_URI_UMAMI_DEV | sed "s#://#://$REDIS_USERNAME_UMAMI_DEV:$REDIS_PASSWORD_UMAMI_DEV@#")"
else
  export REDIS_URL="$REDIS_URI_UMAMI_DEV"
fi

# Debug statement to print the DATABASE_URL
# echo "DATABASE_URL: $DATABASE_URL"


if [ $PRISMA_EXIT_CODE -ne 0 ]; then
  echo "Failed to connect to the database. See /tmp/prisma_output.log for details." >> /tmp/run_error.log
else
  echo "Successfully pushed Prisma schema to the database." >> /tmp/prisma_output.log
fi

# Start the application
yarn start-docker
