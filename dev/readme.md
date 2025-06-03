# Omnitruck Development Environment

This directory contains everything you need to set up a local development environment for the Omnitruck application. The development environment uses Docker to ensure consistency and make it easy to get started.

## What is Omnitruck?

Omnitruck is Chef's package delivery API service that serves metadata about Chef Software Inc. packages and provides download URLs. This service helps clients find the correct package for their platform and version.

## Files in this Directory

### Docker Configuration Files

- `docker-compose.yml` - Defines the services (Redis and Omnitruck) that make up the development environment, their network configuration, and volume mappings.
- `Dockerfile.omnitruck` - Defines how to build the container for the Omnitruck application. Uses Ruby 3.1.6 Alpine as a base and sets up the necessary environment.
- `Dockerfile.redis` - Defines how to build the Redis container that's used for caching package information.
- `redis.conf` - Configuration file for the Redis server with settings for memory management, persistence, and network access.

### Scripts

- `rebuild.sh` - Script to fully rebuild the Docker containers from scratch. This is useful when you need a clean environment or after significant changes.
- `start-dev.sh` - Script to start the development environment and run the poller to populate the Redis cache with package information.
- `entrypoint.sh` - Script that runs when the Omnitruck container starts, setting up Bundler configuration and Git settings.

### Other Files

- `vendor/` - Directory for gem dependencies (created when you first run the environment).

## Getting Started

Follow these steps to set up your development environment:

### Prerequisites

1. Install Docker and Docker Compose on your system.
2. Make sure ports 9393 and 6379 are available on your machine (or change the port mappings in docker-compose.yml).

### Step 1: Clone the Repository

If you haven't already:

```bash
git clone https://github.com/chef/omnitruck.git
cd omnitruck
```

### Step 2: Start the Development Environment

Option 1 - Using the start script (recommended for first-time setup):

```bash
cd dev
./start-dev.sh
```

Option 2 - Using Docker Compose directly:

```bash
cd dev
docker-compose up -d
```

This will:
- Build and start the Redis and Omnitruck containers
- Mount your local codebase into the Omnitruck container
- Make the Omnitruck API available at http://localhost:9393

### Step 3: Populate the Redis Cache

The API needs data in Redis to function properly. You can populate it by running the poller:

```bash
docker-compose exec omnitruck bundle exec ./poller -e development
```

The `start-dev.sh` script does this for you automatically.

### Step 4: Test the API

Once everything is running, you can test the API:

```bash
curl "http://localhost:9393/stable/chef/metadata?p=ubuntu&pv=22.04&m=x86_64"
```

This should return metadata for the latest stable Chef client for Ubuntu 22.04 on x86_64 architecture.

## Development Workflow

1. **Make Code Changes**: Edit the files in your local repository. The changes will be immediately available in the container due to the volume mount.

2. **Restart the Application**: If you make changes to Ruby code, restart the application:

```bash
docker-compose restart omnitruck
```

3. **Rebuild (if necessary)**: If you make changes to dependencies (Gemfile) or Docker configuration, rebuild the environment:

```bash
./rebuild.sh
```

## Troubleshooting

### Checking Logs

View the logs from both containers:

```bash
docker-compose logs
```

Or for a specific container:

```bash
docker-compose logs omnitruck
docker-compose logs redis
```

### Access the Container Shell

For debugging inside the Omnitruck container:

```bash
docker-compose exec omnitruck bash
```

### Clear Redis Cache

If you need to clear the Redis cache:

```bash
docker-compose exec redis redis-cli FLUSHALL
```

### Complete Rebuild

If your environment is in a bad state, perform a complete rebuild:

```bash
./rebuild.sh
```

## Testing Amazon Linux 2 Hotfix

To test the Amazon Linux 2 hotfix for Chef 18.7.10, use the following command:

```bash
curl "http://localhost:9393/stable/chef/metadata?p=amazon&pv=2&m=x86_64&v=18.7.10"
```

This should validate that the hotfix is working correctly by providing the appropriate metadata for Chef 18.7.10 on Amazon Linux 2.