# Environment-Specific Run Scripts

## Overview

This setup uses separate run scripts for dev and prod environments to handle different NAIS database naming conventions without conflicts.

## Files

### 1. `run.sh` (Production)

- Uses `REOPS_UMAMI_BETA` environment variables
- For production deployment
- Connects to `reops-umami-beta` database and Valkey instances
- Default script (for backward compatibility)

### 2. `run-dev.sh` (Development)

- Uses `UMAMI_DEV` environment variables
- For dev deployment
- Connects to `reops-dev` database and Valkey instances

## How It Works

### Dockerfile

The Dockerfile now:

1. Copies both run scripts (`run.sh` and `run-dev.sh`)
2. Makes them both executable
3. Uses a dynamic CMD that reads the `RUN_SCRIPT` environment variable:
   ```dockerfile
   CMD ["/bin/bash", "-c", "/app/${RUN_SCRIPT:-run.sh}"]
   ```
   - Defaults to `run.sh` if `RUN_SCRIPT` is not set (production/backward compatibility)
   - Runs the specified script when `RUN_SCRIPT` is set

### NAIS Configuration

#### `.nais/nais-dev.yaml`

```yaml
env:
  - name: "RUN_SCRIPT"
    value: "run-dev.sh"
  # ... other env vars
```

#### `.nais/nais-prod.yaml`

```yaml
# No RUN_SCRIPT variable needed - defaults to run.sh
env:
  - name: "DATABASE_TYPE"
    value: "postgresql"
  # ... other env vars
```

## Environment Variable Differences

| Variable Type     | Dev (`run-dev.sh`)                           | Prod (`run.sh`)                                            |
| ----------------- | -------------------------------------------- | ---------------------------------------------------------- |
| Database Host     | `NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_HOST`     | `NAIS_DATABASE_REOPS_UMAMI_BETA_REOPS_UMAMI_BETA_HOST`     |
| Database Password | `NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_PASSWORD` | `NAIS_DATABASE_REOPS_UMAMI_BETA_REOPS_UMAMI_BETA_PASSWORD` |
| SSL Key           | `NAIS_DATABASE_UMAMI_DEV_UMAMI_DEV_SSLKEY`   | `NAIS_DATABASE_REOPS_UMAMI_BETA_REOPS_UMAMI_BETA_SSLKEY`   |
| Redis Username    | `REDIS_USERNAME_UMAMI_DEV`                   | `REDIS_USERNAME_REOPS_UMAMI_BETA`                          |
| Redis Password    | `REDIS_PASSWORD_UMAMI_DEV`                   | `REDIS_PASSWORD_REOPS_UMAMI_BETA`                          |
| Redis URI         | `REDIS_URI_UMAMI_DEV`                        | `REDIS_URI_REOPS_UMAMI_BETA`                               |

## Benefits

✅ **No conflicts**: Each environment uses its own script with correct variable names  
✅ **Single Docker image**: Same image works for both dev and prod  
✅ **Environment-specific**: NAIS config determines which script runs  
✅ **Backward compatible**: Falls back to `run.sh` if `RUN_SCRIPT` not set  
✅ **Clear separation**: Easy to maintain and understand environment differences

## Deployment Flow

1. **Build**: Docker builds one image with both scripts
2. **Deploy to Dev**: NAIS sets `RUN_SCRIPT=run-dev.sh` → uses dev variables
3. **Deploy to Prod**: No `RUN_SCRIPT` set → defaults to `run.sh` → uses prod variables

## Testing

After deployment, verify the correct script is being used by checking the container logs:

- Dev should show connections to `reops-dev` database
- Prod should show connections to `reops-umami-beta` database
