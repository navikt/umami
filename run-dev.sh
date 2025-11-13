#!/bin/bash

# Enable Prisma debugging (optional - remove if you don't need it)
export DEBUG="prisma:*:info"

# Export REDIS_URL for the REDIS instance using the URI and credentials
if [[ -n "$REDIS_USERNAME_UMAMI_DEV" && -n "$REDIS_PASSWORD_UMAMI_DEV" ]]; then
    export REDIS_URL="$(echo $REDIS_URI_UMAMI_DEV | sed "s#://#://$REDIS_USERNAME_UMAMI_DEV:$REDIS_PASSWORD_UMAMI_DEV@#")"
else
    export REDIS_URL="$REDIS_URI_UMAMI_DEV"
fi

# Debug output
echo "REDIS_URL: $(echo $REDIS_URL | sed 's/:[^:@]*@/:****@/')"

# Start the application
echo "Starting application..."
yarn start-docker