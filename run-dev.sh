#!/bin/bash

# Enable Prisma debugging (optional - remove if you don't need it)
export DEBUG="prisma:*:info"

# Debug: Print the original DATABASE_URL from NAIS (with password masked)
echo "Original NAIS DATABASE_URL: $(echo $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_URL | sed 's/:[^:@]*@/:****@/')"

# Use the full DATABASE_URL provided by NAIS
export DATABASE_URL="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_URL"
export DATABASE_HOST="$NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST"

# Debug: Extract and display the hostname from the connection string
HOSTNAME=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
echo "Extracted hostname from DATABASE_URL: $HOSTNAME"
echo "NAIS provided host: $NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST"

# Warning if localhost is detected
if [[ "$HOSTNAME" == "localhost" || "$HOSTNAME" == "127.0.0.1" ]]; then
    echo "⚠️  WARNING: DATABASE_URL contains localhost!"
    echo "This will cause certificate validation errors with Google Cloud SQL."
    echo "Expected hostname should be: *.europe-north1.sql.goog"
    echo ""
    echo "Please check your NAIS configuration to ensure DATABASE_URL has the correct Cloud SQL hostname."
fi

# Export REDIS_URL for the REDIS instance using the URI and credentials
if [[ -n "$REDIS_USERNAME_UMAMI_DEV" && -n "$REDIS_PASSWORD_UMAMI_DEV" ]]; then
    export REDIS_URL="$(echo $REDIS_URI_UMAMI_DEV | sed "s#://#://$REDIS_USERNAME_UMAMI_DEV:$REDIS_PASSWORD_UMAMI_DEV@#")"
else
    export REDIS_URL="$REDIS_URI_UMAMI_DEV"
fi

# Debug statement to print the DATABASE_URL (with password masked)
echo "DATABASE_URL: $(echo $DATABASE_URL | sed 's/:[^:@]*@/:****@/')"
echo "REDIS_URL: $(echo $REDIS_URL | sed 's/:[^:@]*@/:****@/')"

# Start the application
echo "Starting application..."
yarn start-docker